// node tools/media.js
//
// Draws the addon's own textures (media/*.tga) from the shapes on the concept
// page (docs/clean-slate.html): the rank's wing, the quest ring, the red glow,
// the Banner's notch, and the small icons that sit in a line of text. Each is
// also written as a PNG for the screenshot tool (tools/screenshots/media/).
//
// Drawn in Chromium's canvas, written as 32-bit TGA (origin bottom left,
// straight alpha), which the game reads as it is.
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');

const root = path.join(__dirname, '..');
const outTga = path.join(root, 'media');
const outPng = path.join(__dirname, 'screenshots/media');

// Every texture: its size in pixels and how to draw it. `white` ones are
// tinted in the game (SetVertexColor, or the colour in a |T code).
const TEXTURES = {
  // the wing on the frame's corner, gold for elites and silver for rares
  'wing-elite': { w: 64, h: 64, draw: 'wing', args: ['#e7b93e', '#5a3d0a'] },
  'wing-rare': { w: 64, h: 64, draw: 'wing', args: ['#cfd6e2', '#5c6472'] },
  // the quest ring: its dark ground, and the arc in 32 steps (8 x 4)
  'ring-track': { w: 64, h: 64, draw: 'ringTrack' },
  'ring-arc': { w: 512, h: 256, draw: 'ringArc', white: true },
  // the soft red glow round the frame while a unit is after you: the frame's
  // edge sits 16 pixels in from each side; the game stretches the middle
  'glow': { w: 64, h: 64, draw: 'glow' },
  // the Banner's notch, pointing up at the nameplate: its ground and its edge
  'notch-fill': { w: 32, h: 16, draw: 'notchFill', white: true },
  'notch-edge': { w: 32, h: 16, draw: 'notchEdge', white: true },
  // a shine over the bar's fill
  'gloss': { w: 16, h: 32, draw: 'gloss' },
  // small icons for a line of text
  'arrow': { w: 32, h: 32, draw: 'arrow', white: true },
  'pvp': { w: 32, h: 32, draw: 'pvp' },
  'pin': { w: 32, h: 32, draw: 'pin' },
  'diamond': { w: 16, h: 16, draw: 'diamond' },
};

// runs in the page: draws one texture and hands back its pixels
function paint(name, spec) {
  const { w, h } = spec;
  const cv = document.createElement('canvas');
  cv.width = w; cv.height = h;
  const g = cv.getContext('2d');
  const D = {
    wing(fill, edge) {
      const k = w / 30;
      g.scale(k, k);
      g.fillStyle = fill; g.strokeStyle = edge; g.lineJoin = 'round';
      const a = new Path2D('M2 28C2 14 9 5 27 2c-8 4-13 8-15.5 14C15 12 19 10 25 9.5 17 13 13 18 11.5 26 9 23 6 25 2 28z');
      g.lineWidth = 0.8; g.fill(a); g.stroke(a);
      const b = new Path2D('M4 24c1-6 3-10 7-13-2 4-3 7-3 11z');
      g.globalAlpha = 0.75; g.lineWidth = 0.6; g.fill(b); g.stroke(b);
    },
    // as the concept: a 28 wide ring, radius 11.5, three wide
    ringTrack() {
      const k = w / 28;
      g.beginPath(); g.arc(w / 2, h / 2, 11.5 * k, 0, Math.PI * 2);
      g.fillStyle = '#0e1020'; g.fill();
      g.lineWidth = 3 * k; g.strokeStyle = '#3a3320'; g.stroke();
    },
    ringArc() {
      const s = 64, k = s / 28;
      for (let i = 1; i <= 32; i++) {
        const cx = ((i - 1) % 8) * s + s / 2, cy = Math.floor((i - 1) / 8) * s + s / 2;
        g.beginPath();
        g.arc(cx, cy, 11.5 * k, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * i / 32);
        g.lineWidth = 3 * k; g.strokeStyle = '#fff'; g.lineCap = 'butt'; g.stroke();
      }
    },
    // box-shadow 0 0 12px 2px: the blurred edge of a box two pixels bigger
    glow() {
      const img = g.createImageData(w, h), M = 16, r = 3;
      const erf = x => { const t = 1 / (1 + 0.3275911 * Math.abs(x)); const y = 1 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * Math.exp(-x * x); return x >= 0 ? y : -y; };
      const peak = 0.5 * (1 + erf(2 / (6 * Math.SQRT2)));
      for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
        // distance outside a rounded box from M to w - M
        const px = x + 0.5, py = y + 0.5;
        const qx = Math.max(M + r - px, 0, px - (w - M - r)), qy = Math.max(M + r - py, 0, py - (h - M - r));
        const d = Math.hypot(qx, qy) - r;
        const a = d <= 0 ? 0 : 0.5 * (1 - erf((d - 2) / (6 * Math.SQRT2))) / peak;
        const o = (y * w + x) * 4;
        img.data[o] = 255; img.data[o + 1] = 50; img.data[o + 2] = 35; img.data[o + 3] = Math.round(255 * Math.min(1, a));
      }
      g.putImageData(img, 0, 0);
    },
    notchFill() {
      g.beginPath(); g.moveTo(0, h); g.lineTo(w / 2, 1); g.lineTo(w, h); g.closePath();
      g.fillStyle = '#fff'; g.fill();
    },
    notchEdge() {
      g.beginPath(); g.moveTo(1, h - 4); g.lineTo(w / 2, 2); g.lineTo(w - 1, h - 4);
      g.lineWidth = 2; g.strokeStyle = '#fff'; g.lineJoin = 'miter'; g.stroke();
    },
    // linear-gradient(rgba(255,255,255,.22), rgba(0,0,0,.28)), as over the concept's bar
    gloss() {
      const img = g.createImageData(w, h);
      for (let y = 0; y < h; y++) {
        const t = (y + 0.5) / h, a = 0.22 * (1 - t) + 0.28 * t, c = a > 0 ? 0.22 * (1 - t) / a : 0;
        for (let x = 0; x < w; x++) {
          const o = (y * w + x) * 4;
          img.data[o] = img.data[o + 1] = img.data[o + 2] = Math.round(255 * c);
          img.data[o + 3] = Math.round(255 * a);
        }
      }
      g.putImageData(img, 0, 0);
    },
    arrow() {
      const k = w / 16;
      g.scale(k, k);
      g.strokeStyle = '#fff'; g.lineWidth = 1.7; g.lineCap = 'round'; g.lineJoin = 'round';
      g.beginPath(); g.moveTo(2.2, 8); g.lineTo(13.2, 8); g.stroke();
      g.beginPath(); g.moveTo(9, 3.8); g.lineTo(13.4, 8); g.lineTo(9, 12.2); g.stroke();
    },
    pvp() {
      const k = w / 16;
      g.scale(k, k);
      g.fillStyle = '#c0392b'; g.fill(new Path2D('M3 1.5h1.4v13H3z'));
      const f = new Path2D('M4.4 2h9l-2.4 3.2L13.4 8.5h-9z');
      g.fillStyle = '#e74c3c'; g.strokeStyle = '#5c120c'; g.lineWidth = 0.6; g.fill(f); g.stroke(f);
    },
    pin() {
      const k = w / 16;
      g.scale(k, k);
      g.fillStyle = '#9fd6ff';
      g.fill(new Path2D('M8 1a5 5 0 0 0-5 5c0 3.8 5 9 5 9s5-5.2 5-9a5 5 0 0 0-5-5zm0 7a2 2 0 1 1 0-4 2 2 0 0 1 0 4z'), 'evenodd');
    },
    diamond() {
      g.beginPath(); g.moveTo(w / 2, 0.5); g.lineTo(w - 0.5, h / 2); g.lineTo(w / 2, h - 0.5); g.lineTo(0.5, h / 2); g.closePath();
      g.fillStyle = '#cfd6e2'; g.fill();
    },
  };
  D[spec.draw](...(spec.args || []));
  const px = g.getImageData(0, 0, w, h).data;
  return { png: cv.toDataURL('image/png'), px: Array.from(px) };
}

// Transparent pixels take the colour of their neighbours (white for tinted
// textures), so the game's filtering doesn't draw a dark fringe.
function bleed(px, w, h, white) {
  if (white) {
    for (let i = 0; i < px.length; i += 4) px[i] = px[i + 1] = px[i + 2] = 255;
    return px;
  }
  for (let pass = 0; pass < 4; pass++) {
    const next = px.slice();
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const o = (y * w + x) * 4;
      if (px[o + 3] > 0) continue;
      let r = 0, g = 0, b = 0, n = 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const X = x + dx, Y = y + dy;
        if (X < 0 || Y < 0 || X >= w || Y >= h) continue;
        const p = (Y * w + X) * 4;
        if (px[p + 3] > 0 || (px[p] + px[p + 1] + px[p + 2]) > 0) { r += px[p]; g += px[p + 1]; b += px[p + 2]; n++; }
      }
      if (n) { next[o] = r / n; next[o + 1] = g / n; next[o + 2] = b / n; }
    }
    px = next;
  }
  return px;
}

function tga(px, w, h) {
  const head = Buffer.alloc(18);
  head[2] = 2; // uncompressed true colour
  head.writeUInt16LE(w, 12);
  head.writeUInt16LE(h, 14);
  head[16] = 32;
  head[17] = 8; // 8 bits of alpha, rows from the bottom
  const body = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const s = (y * w + x) * 4, d = ((h - 1 - y) * w + x) * 4;
    body[d] = Math.round(px[s + 2]); body[d + 1] = Math.round(px[s + 1]); body[d + 2] = Math.round(px[s]); body[d + 3] = px[s + 3];
  }
  return Buffer.concat([head, body]);
}

(async () => {
  fs.mkdirSync(outTga, { recursive: true });
  fs.mkdirSync(outPng, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const [name, spec] of Object.entries(TEXTURES)) {
    const { png, px } = await page.evaluate(([f, n, s]) => { eval('var paint = ' + f); return paint(n, s); }, [paint.toString(), name, spec]);
    fs.writeFileSync(path.join(outTga, name + '.tga'), tga(bleed(px, spec.w, spec.h, spec.white), spec.w, spec.h));
    fs.writeFileSync(path.join(outPng, name + '.png'), Buffer.from(png.split(',')[1], 'base64'));
    console.log(`media/${name}.tga  ${spec.w}x${spec.h}`);
  }
  await browser.close();
})();
