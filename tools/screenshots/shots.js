// node tools/screenshots/shots.js
//
// Hovers a few creatures headless (shots.lua on tests/mock.lua), then draws what
// the card showed as HTML and photographs it with Chromium into
// assets/screenshots/. The layout follows Card.lua and Options.lua (sizes,
// offsets, colours); fonts, textures and the creatures are stand-ins, since the
// game's own files aren't available outside the game.
const fs = require('fs'), path = require('path'), os = require('os');
const { execFileSync } = require('child_process');
const { lua, lauxlib, lualib, to_luastring } = require(path.join(__dirname, '../../tests/node_modules/fengari'));

const root = path.join(__dirname, '../..');
const out = path.join(root, 'assets/screenshots');
const chromium = process.env.CHROMIUM || '/opt/pw-browsers/chromium';

// ---------------------------------------------------------------- run the addon
const toc = fs.readFileSync(path.join(root, 'Krakentip.toc'), 'utf8').split(/\r?\n/).filter(l => l.trim() && !l.startsWith('#'));
const longString = s => { let eq = ''; while (s.includes(']' + eq + ']')) eq += '='; return '[' + eq + '[\n' + s + ']' + eq + ']'; };
let src = 'TOC = {' + toc.map(f => JSON.stringify(f)).join(',') + '}\nFILES = {}\n';
for (const f of toc) src += 'FILES[' + JSON.stringify(f) + '] = ' + longString(fs.readFileSync(path.join(root, f), 'utf8')) + '\n';
src += fs.readFileSync(path.join(root, 'tests/mock.lua'), 'utf8') + '\n';
src += 'function DEFAULT_CHAT_FRAME:AddMessage() end\n'; // quiet
src += fs.readFileSync(path.join(__dirname, 'shots.lua'), 'utf8');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring('=shots')) !== 0 || lua.lua_pcall(L, 0, 0, 0) !== 0) {
  console.error('LUA ERROR:', lua.lua_tojsstring(L, -1));
  process.exit(1);
}
lua.lua_getglobal(L, to_luastring('SHOT_JSON'));
const data = JSON.parse(lua.lua_tojsstring(L, -1));
if (data.errors) { console.error('the addon raised errors'); process.exit(1); }

// ---------------------------------------------------------------- look
const C = { gold: '#ffd100', dim: '#c7b899', faint: '#807561' };
const rgb = c => `rgb(${c.map(v => Math.round(v * 255)).join(',')})`;
const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;');
const STONE = `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='2'/><feColorMatrix values='0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 .55 0'/></filter><rect width='160' height='160' filter='url(%23n)'/></svg>")`;

const CSS = `
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: 'Carlito', 'Liberation Sans', sans-serif; color: #fff; }
.scene { position: relative; overflow: hidden;
  background: radial-gradient(ellipse at 40% 115%, #4a5a2e 0%, #2a3a22 30%, #16201a 60%, #0b0f14 100%); }
.scene::before { content: ''; position: absolute; inset: 0;
  background: radial-gradient(circle at 15% 25%, rgba(255,255,255,.05), transparent 35%), radial-gradient(circle at 70% 60%, rgba(0,0,0,.45), transparent 45%); }
.dialog { position: absolute; border: 10px solid; border-image: linear-gradient(180deg, #f5d77a, #c99a2e 45%, #7a5714) 1;
  background: #3b342d ${STONE}; box-shadow: 0 0 0 2px #120e09, 0 10px 30px rgba(0,0,0,.7), inset 0 0 40px rgba(0,0,0,.55); }
.title { font-family: 'Caladea', 'Bitstream Charter', serif; text-shadow: 1px 1px 1px #000; }
.t { position: absolute; white-space: pre; text-shadow: 1px -1px 0 rgba(0,0,0,.8); }
.out { text-shadow: -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000; }
.caption { position: absolute; left: 0; right: 0; bottom: 12px; text-align: center; font-size: 14px; color: #c7b899; text-shadow: 0 1px 2px #000; }
.cursor { position: absolute; width: 0; height: 0; border-left: 7px solid transparent; border-right: 7px solid transparent;
  border-bottom: 18px solid #e8d9a8; transform: rotate(-28deg); filter: drop-shadow(0 1px 1px #000); }
.check { position: absolute; width: 16px; height: 16px; border: 1px solid #8a7a50; background: #1a1612; border-radius: 2px; }
.check.on::after { content: ''; position: absolute; left: 4px; top: 0; width: 5px; height: 10px; border: solid ${C.gold}; border-width: 0 3px 3px 0; transform: rotate(40deg); }
.radio { position: absolute; width: 16px; height: 16px; border: 1px solid #8a7a50; background: #1a1612; border-radius: 50%; }
.radio.on::after { content: ''; position: absolute; left: 3px; top: 3px; width: 8px; height: 8px; border-radius: 50%; background: ${C.gold}; }
.btn { position: absolute; height: 24px; line-height: 22px; text-align: center; font-size: 12px; color: ${C.gold};
  background: linear-gradient(#8b1a12, #4a0a06); border: 1px solid #c99a2e; border-radius: 3px; text-shadow: 0 1px 1px #000; }
`;

// ---------------------------------------------------------------- the card (Card.lua)
const WIDTH = 236, PAD = 8, HEAD = 42, BAR_H = 16, ROW_H = 16;
function cardHeight(c) {
  let y = HEAD + 6 + BAR_H + 5 + c.rows.length * ROW_H;
  if (c.quests.length) y += 9 + c.quests.length * 14;
  return y + PAD;
}
function cardHTML(c) {
  const h = cardHeight(c);
  let s = `<div class="dialog" style="left:-7px;top:-7px;width:${WIDTH + 14}px;height:${h + 14}px"></div>
    <div style="position:absolute;left:2px;right:2px;top:2px;height:${HEAD}px;background:rgba(0,0,0,.45)"></div>`;
  // the badge: level in a gold ring, or a skull
  s += `<div style="position:absolute;left:${PAD}px;top:7px;width:30px;height:30px;border-radius:50%;border:2px solid #c99a2e;
    background:radial-gradient(circle at 40% 35%,#3a2a20,#120c08);display:flex;align-items:center;justify-content:center;box-shadow:0 0 0 1px #000">
    ${c.level != null ? `<span class="out" style="font-size:12px;font-weight:700;color:${rgb(c.levelColor)}">${c.level}</span>`
      : `<span style="font-size:15px;filter:grayscale(.2)">💀</span>`}</div>`;
  s += `<div class="t title" style="left:${PAD + 37}px;top:6px;font-size:16px;color:${rgb(c.nameColor)}">${esc(c.name)}</div>`;
  s += `<div class="t" style="left:${PAD + 37}px;top:25px;font-size:11px;color:${C.dim}">${esc(c.sub)}${c.tag ? ` <span style="display:inline-block;margin-left:3px;padding:0 5px;height:12px;line-height:12px;font-size:9px;font-weight:700;color:#1a1208;background:${C.gold};text-shadow:none;vertical-align:1px">${esc(c.tag)}</span>` : ''}</div>`;
  // health
  const by = HEAD + 6;
  s += `<div style="position:absolute;left:${PAD}px;top:${by}px;width:${WIDTH - PAD * 2}px;height:${BAR_H}px;background:rgba(0,0,0,.65);box-shadow:0 0 0 1px rgba(255,209,0,.5)">
    <div style="height:100%;width:${Math.round(c.fill * 100)}%;background:linear-gradient(180deg,#e33a2a,#b81a12 55%,#7a0d09)"></div></div>
    <div class="t out" style="left:${PAD}px;width:${WIDTH - PAD * 2}px;top:${by + 1}px;text-align:center;font-size:11px;font-weight:700">${esc(c.hp)}</div>`;
  let y = by + BAR_H + 5;
  for (const [label, value, color] of c.rows) {
    s += `<div class="t" style="left:${PAD}px;top:${y + 1}px;font-size:11px;color:${C.dim}">${esc(label)}</div>
      <div class="t" style="right:${PAD}px;top:${y + 1}px;font-size:11px;color:${rgb(color)}">${esc(value)}</div>`;
    y += ROW_H;
  }
  if (c.quests.length) {
    y += 4;
    s += `<div style="position:absolute;left:${PAD}px;right:${PAD}px;top:${y}px;height:1px;background:rgba(255,209,0,.22)"></div>`;
    y += 5;
    for (const [text, color] of c.quests) {
      s += `<div class="t" style="left:${PAD}px;top:${y}px;font-size:11px;color:${rgb(color)}">${esc(text)}</div>`;
      y += 14;
    }
  }
  return { html: `<div style="position:relative;width:${WIDTH}px;height:${h}px">${s}</div>`, h };
}

// a stand-in creature with its nameplate
function creature(x, y, name, color, hp, scale = 1) {
  return `<div style="position:absolute;left:${x}px;top:${y}px;transform:scale(${scale});transform-origin:top left">
    <div class="t" style="left:10px;top:-34px;width:150px;text-align:center;font-size:11px;color:${color}">${esc(name)}</div>
    <div style="position:absolute;left:35px;top:-18px;width:100px;height:6px;border:1px solid #000;background:#300"><div style="height:100%;width:${hp}%;background:#d22"></div></div>
    <div style="position:absolute;left:20px;top:30px;width:120px;height:46px;border-radius:50% 45% 40% 40%;background:radial-gradient(circle at 40% 30%,#5a5148,#221d19)"></div>
    <div style="position:absolute;left:118px;top:14px;width:46px;height:36px;border-radius:50% 60% 40% 50%;background:radial-gradient(circle at 40% 40%,#615749,#221d19)"></div>
    ${[34, 56, 104, 124].map(l => `<div style="position:absolute;left:${l}px;top:66px;width:9px;height:28px;background:#1d1915;border-radius:3px"></div>`).join('')}
  </div>`;
}

const SCALE = 1.5; // the card drawn a bit bigger than life, so it reads in the README

function mouseScene() {
  const W = 900, H = 500, c = data.cards.wolf, card = cardHTML(c);
  const cx = 360, cy = 270;
  return { w: W, h: H, html: `<div class="scene" style="width:${W}px;height:${H}px">
    ${creature(220, 220, c.name, '#ff4d40', 62, 1.2)}
    <div class="cursor" style="left:${cx}px;top:${cy}px"></div>
    <div style="position:absolute;left:${cx + 22 * SCALE}px;top:${cy - 8 * SCALE - card.h * SCALE}px;transform:scale(${SCALE});transform-origin:top left">${card.html}</div>
    <div class="caption">Next to the mouse: the card follows the cursor, so your eyes stay on the fight.</div></div>` };
}

function spotScene() {
  const W = 900, H = 500, c = data.cards.wolf, card = cardHTML(c);
  const s = 1.15;
  return { w: W, h: H, html: `<div class="scene" style="width:${W}px;height:${H}px">
    ${creature(250, 200, c.name, '#ff4d40', 62, 1.2)}
    <div class="cursor" style="left:390px;top:250px"></div>
    <div style="position:absolute;left:${W - 30 - WIDTH * s}px;top:${H - 50 - card.h * s}px;transform:scale(${s});transform-origin:top left">${card.html}</div>
    <div class="caption" style="text-align:left;left:24px">Or where the game puts tooltips (move that in Edit Mode).</div></div>` };
}

function pairScene() {
  const W = 900, H = 400, a = cardHTML(data.cards.boss), b = cardHTML(data.cards.boar);
  return { w: W, h: H, html: `<div class="scene" style="width:${W}px;height:${H}px">
    <div style="position:absolute;left:60px;top:50px;transform:scale(${SCALE});transform-origin:top left">${a.html}</div>
    <div style="position:absolute;left:${W - 60 - WIDTH * SCALE}px;top:50px;transform:scale(${SCALE});transform-origin:top left">${b.html}</div>
    <div class="caption">A boss gets a skull (its health hidden here, so just the bar). A neutral creature gets a yellow name.</div></div>` };
}

// ---------------------------------------------------------------- the options window (Options.lua)
const OW = 360, OH = 420, OP = 18;
function optionsHTML(o) {
  let s = `<div class="dialog" style="left:-7px;top:-7px;width:${OW + 14}px;height:${OH + 14}px"></div>
    <div style="position:absolute;left:2px;right:2px;top:2px;height:26px;background:rgba(0,0,0,.45)"></div>
    <div class="t title" style="left:${OP}px;top:5px;font-size:19px;color:${C.gold}">Krakentip</div>
    <div class="t" style="left:${OP + 92}px;top:11px;font-size:11px;color:${C.dim}">a card for every enemy</div>
    <div class="t" style="right:8px;top:4px;font-size:16px;color:${C.dim};font-weight:700">✕</div>`;
  const heading = (text, y) => `<div class="t" style="left:${OP}px;top:${y}px;font-size:13px;color:${C.gold}">${text}</div>
    <div style="position:absolute;left:${OP}px;right:${OP}px;top:${y + 17}px;height:1px;background:rgba(255,209,0,.22)"></div>`;
  let y = 40;
  s += heading('Where the card shows', y);
  y += 26;
  for (const [label, hint, on] of o.radio) {
    s += `<div class="radio ${on ? 'on' : ''}" style="left:${OP}px;top:${y}px"></div>
      <div class="t" style="left:${OP + 22}px;top:${y + 1}px;font-size:12px">${esc(label)}</div>
      <div class="t" style="left:${OP + 22}px;top:${y + 17}px;font-size:11px;color:${C.dim}">${esc(hint)}</div>`;
    y += 36;
  }
  y += 8;
  s += heading('On the card', y);
  y += 24;
  o.checks.forEach(([label, on], i) => {
    if (i === 4) { y += 6; s += heading('The card', y); y += 24; }
    s += `<div class="check ${on ? 'on' : ''}" style="left:${OP}px;top:${y + 2}px"></div>
      <div class="t" style="left:${OP + 22}px;top:${y + 3}px;font-size:12px">${esc(label)}</div>`;
    y += 24;
  });
  s += `<div class="t" style="left:${OP + 2}px;top:${y + 4}px;font-size:12px">Size</div>
    <div class="t" style="left:${OP + 66}px;top:${y + 1}px;font-size:15px;color:${C.dim}">−</div>
    <div class="t" style="left:${OP + 84}px;width:44px;text-align:center;top:${y + 4}px;font-size:12px;color:${C.gold}">${esc(o.scale)}</div>
    <div class="t" style="left:${OP + 136}px;top:${y + 1}px;font-size:15px;color:${C.dim}">+</div>`;
  y += 34;
  s += `<div class="btn" style="left:${OP}px;top:${y}px;width:180px">${esc(o.sample)}</div>
    <div class="t" style="left:${OP + 190}px;top:${y + 5}px;font-size:11px;color:${C.dim}">/kt sample does the same</div>`;
  return s;
}

function optionsScene() {
  const W = 980, H = 600, card = cardHTML(data.cards.sample);
  return { w: W, h: H, html: `<div class="scene" style="width:${W}px;height:${H}px">
    <div style="position:absolute;left:60px;top:50px;width:${OW}px;height:${OH}px">${optionsHTML(data.options)}</div>
    <div class="cursor" style="left:520px;top:380px"></div>
    <div style="position:absolute;left:${520 + 22 * SCALE}px;top:${372 - card.h * SCALE}px;transform:scale(${SCALE});transform-origin:top left">${card.html}</div>
    <div class="caption">/kt opens the options. The sample card shows the settings without an enemy around.</div></div>` };
}

// ---------------------------------------------------------------- photograph
const scenes = [
  ['1-card-at-mouse', mouseScene()],
  ['2-card-tooltip-spot', spotScene()],
  ['3-boss-and-neutral', pairScene()],
  ['4-options', optionsScene()],
];
fs.mkdirSync(out, { recursive: true });
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'ktshots-'));
for (const [name, sc] of scenes) {
  const html = path.join(tmp, name + '.html');
  fs.writeFileSync(html, `<!doctype html><html><head><meta charset="utf-8"><style>${CSS}</style></head><body>${sc.html}</body></html>`);
  const raw = path.join(tmp, name + '.png');
  execFileSync(chromium, ['--headless', '--no-sandbox', '--disable-gpu', '--hide-scrollbars', `--window-size=${sc.w},${sc.h + 200}`,
    '--force-device-scale-factor=1', `--screenshot=${raw}`, 'file://' + html], { stdio: 'ignore' });
  // crop the extra height Chromium needs for its own frame
  execFileSync('python3', ['-c', `from PIL import Image; Image.open(r'${raw}').crop((0,0,${sc.w},${sc.h})).save(r'${path.join(out, name + '.png')}')`]);
  console.log('wrote', path.relative(root, path.join(out, name + '.png')));
}
