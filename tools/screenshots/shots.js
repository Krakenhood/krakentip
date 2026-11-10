// node tools/screenshots/shots.js
//
// Hovers a few units headless in each look (shots.lua on tests/mock.lua), then
// draws each card from its parts, where Layouts.lua put them, and photographs
// it with Chromium into assets/screenshots/. Fonts, textures and the
// creatures are stand-ins, since the game's own files aren't available
// outside the game.
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
const rgb = c => c ? `rgb(${c.map(v => Math.round(v * 255)).join(',')})` : '#fff';
const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;');
// the game's colour codes as spans
const codes = s => esc(s).replace(/\|c[0-9a-f]{2}([0-9a-f]{6})(.*?)\|r/gi, (_, hex, t) => `<span style="color:#${hex}">${t}</span>`);
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
.thin { position: absolute; inset: 0; background: rgba(26,23,20,.94); border: 2px solid rgba(255,209,0,.85); border-radius: 3px;
  box-shadow: inset 0 0 0 1px rgba(0,0,0,.6), 0 4px 12px rgba(0,0,0,.6); }
.title { font-family: 'Caladea', 'Bitstream Charter', serif; text-shadow: 1px 1px 1px #000; }
.t { position: absolute; white-space: pre; line-height: 1.15; text-shadow: 1px -1px 0 rgba(0,0,0,.8); }
.out { text-shadow: -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000; }
.tag { position: absolute; text-align: center; font-weight: 700; color: #1a1208; background: ${C.gold}; }
.caption { position: absolute; left: 0; right: 0; bottom: 12px; text-align: center; font-size: 14px; color: #c7b899; text-shadow: 0 1px 2px #000; }
.label { position: absolute; font-size: 14px; color: ${C.gold}; text-shadow: 0 1px 2px #000; white-space: nowrap; }
.cursor { position: absolute; width: 0; height: 0; border-left: 7px solid transparent; border-right: 7px solid transparent;
  border-bottom: 18px solid #e8d9a8; transform: rotate(-28deg); filter: drop-shadow(0 1px 1px #000); }
.check { position: absolute; width: 16px; height: 16px; border: 1px solid #8a7a50; background: #1a1612; border-radius: 2px; }
.check.on::after { content: ''; position: absolute; left: 4px; top: 0; width: 5px; height: 10px; border: solid ${C.gold}; border-width: 0 3px 3px 0; transform: rotate(40deg); }
.radio { position: absolute; width: 16px; height: 16px; border: 1px solid #8a7a50; background: #1a1612; border-radius: 50%; }
.radio.on::after { content: ''; position: absolute; left: 3px; top: 3px; width: 8px; height: 8px; border-radius: 50%; background: ${C.gold}; }
.btn { position: absolute; height: 24px; line-height: 22px; text-align: center; font-size: 12px; color: ${C.gold};
  background: linear-gradient(#8b1a12, #4a0a06); border: 1px solid #c99a2e; border-radius: 3px; text-shadow: 0 1px 1px #000; }
`;

// ---------------------------------------------------------------- a card, part by part (Layouts.lua)
const SHIFT = { TOPLEFT: '', TOPRIGHT: 'transform:translateX(-100%);', TOP: 'transform:translateX(-50%);' };
const skull = size => `<span style="font-size:${size}px;line-height:1">💀</span>`;
const BAR_SHINE = {
  smooth: 'linear-gradient(180deg, rgba(255,255,255,.22), rgba(255,255,255,0) 45%, rgba(0,0,0,.28))',
  flat: 'linear-gradient(transparent, transparent)',
  raid: 'linear-gradient(180deg, rgba(255,255,255,.08), rgba(255,255,255,.3) 50%, rgba(0,0,0,.2))',
  skill: 'repeating-linear-gradient(90deg, rgba(0,0,0,.18) 0 1px, transparent 1px 6px), linear-gradient(180deg, rgba(255,255,255,.35), rgba(0,0,0,.35))',
};
const FACE_TINT = { Beast: ['#8a7a66', '#2b241c'], Humanoid: ['#c9a27e', '#4a3322'], player: ['#9fb6d8', '#26324a'] };

function drawPart(p) {
  const pos = `left:${p.x}px;top:${p.y}px;${p.kind === 'text' || p.kind === 'tag' ? '' : SHIFT[p.point] || ''}`;
  switch (p.kind) {
    case 'text': {
      const w = p.width ? `width:${p.width}px;overflow:hidden;text-overflow:ellipsis;` : '';
      const align = p.justify === 'CENTER' ? 'text-align:center;' : p.justify === 'RIGHT' ? 'text-align:right;' : '';
      const font = p.title ? "font-family:Caladea,'Bitstream Charter',serif;" : '';
      const out = p.outline ? 'text-shadow:-1px -1px 0 #000,1px -1px 0 #000,-1px 1px 0 #000,1px 1px 0 #000;font-weight:700;' : '';
      return `<div class="t" style="${pos}${SHIFT[p.point]}${w}${align}${font}${out}font-size:${p.size}px;color:${rgb(p.color)}">${codes(p.text)}</div>`;
    }
    case 'solid':
      return `<div style="position:absolute;${pos}width:${p.w}px;height:${p.h}px;background:rgba(${p.rgba.slice(0, 3).map(v => Math.round(v * 255)).join(',')},${p.rgba[3]})"></div>`;
    case 'bar':
      return `<div style="position:absolute;${pos}width:${p.w}px;height:${p.h}px;background:rgba(0,0,0,.65);box-shadow:0 0 0 1px ${p.edge ? rgb(p.edge) : 'rgba(255,209,0,.5)'}">
        <div style="height:100%;width:${Math.round(p.fill * 100)}%;background:${BAR_SHINE[p.texture] || BAR_SHINE.smooth}, ${rgb(p.color)}"></div></div>`;
    case 'tag':
      return `<div class="tag" style="${pos}${SHIFT[p.point]}width:${p.w}px;height:${p.size + 3}px;line-height:${p.size + 3}px;font-size:${p.size}px">${esc(p.text)}</div>`;
    case 'skull':
      return `<div class="t" style="${pos}">${skull(p.size)}</div>`;
    case 'ring':
      return `<div style="position:absolute;${pos}width:${p.size}px;height:${p.size}px;border-radius:50%;border:2px solid #c99a2e;
        background:radial-gradient(circle at 40% 35%,#3a2a20,#120c08);display:flex;align-items:center;justify-content:center;box-shadow:0 0 0 1px #000;z-index:2">
        ${p.skull ? skull(p.size * 0.5) : `<span class="out" style="font-size:${p.size >= 26 ? 12 : 10}px;font-weight:700;color:${rgb(p.levelColor)}">${esc(p.level)}</span>`}</div>`;
    case 'face': {
      const [a, b] = FACE_TINT[p.unit] || FACE_TINT[(p.tex || '').includes('Wolf') ? 'Beast' : 'Humanoid'];
      return `<div style="position:absolute;${pos}width:${p.size}px;height:${p.size}px;border-radius:50%;background:radial-gradient(circle at 40% 35%,${a},${b});box-shadow:0 0 0 3px #c99a2e,0 0 0 4px #000"></div>`;
    }
    case 'chip': {
      const key = String(p.icon || '').split('\\').pop();
      const glyph = { Attack: '⚔', ActiveQuestIcon: '?', AvailableQuestIcon: '!', Achievement_Reputation_01: '♥', INV_Shirt_GuildTabard_01: '⚑' }[key] || '◆';
      const tint = { Attack: '#ddd', ActiveQuestIcon: '#ffd100', Achievement_Reputation_01: '#4fd1c5', INV_Shirt_GuildTabard_01: '#7aa35a' }[key] || '#b49a6a';
      return `<div class="t" style="${pos}font-size:10px;color:${rgb(p.color)}"><span style="display:inline-block;width:13px;height:13px;line-height:13px;margin-right:2px;text-align:center;font-size:10px;border-radius:2px;background:#1a1612;box-shadow:0 0 0 1px #6b5a2e;color:${tint}">${glyph}</span>${esc(p.text)}</div>`;
    }
  }
  return '';
}

function cardHTML(c) {
  // the Slate looks: the game's own tooltip ground, the edge in the rank's colour, a red glow when it's after you
  const tipFrame = () => `<div style="position:absolute;inset:-1px;background:rgba(8,9,18,.93);border:1px solid ${rgb(c.edge || [0.44, 0.46, 0.53])};border-radius:3px;
    box-shadow:0 0 0 1px rgba(0,0,0,.85)${c.glow ? ',0 0 12px 2px rgba(255,50,35,.6)' : ''},0 6px 18px rgba(0,0,0,.55)"></div>`;
  const frame = c.look === 'dialog' ? `<div class="dialog" style="left:-7px;top:-7px;width:${c.w + 14}px;height:${c.h + 14}px"></div>`
    : c.look === 'tip' ? tipFrame() : '<div class="thin"></div>';
  return { html: `<div style="position:relative;width:${c.w}px;height:${c.h}px">${frame}${c.parts.map(drawPart).join('')}</div>`, w: c.w, h: c.h };
}
const card = (style, unit) => cardHTML(data.cards[style][unit]);
const at = (x, y, html, scale) => `<div style="position:absolute;left:${x}px;top:${y}px;transform:scale(${scale});transform-origin:top left">${html}</div>`;

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

const SCALE = 1.5; // drawn a bit bigger than life, so it reads in the README

function scene(W, H, inner, caption) {
  W = Math.ceil(W); H = Math.ceil(H);
  return { w: W, h: H, html: `<div class="scene" style="width:${W}px;height:${H}px">${inner}<div class="caption">${caption}</div></div>` };
}

function mouseScene() {
  const c = card('regular', 'wolf'), cx = 360, cy = 290;
  return scene(900, 500, `${creature(220, 240, 'Timberling Ravager', '#ff4d40', 62, 1.2)}
    <div class="cursor" style="left:${cx}px;top:${cy}px"></div>
    ${at(cx + 22 * SCALE, cy - 8 * SCALE - c.h * SCALE, c.html, SCALE)}`,
    'Regular, next to the mouse: the card follows the cursor, so your eyes stay on the fight.');
}

// the Compare window (Compare.lua): every look in two columns, each into the shorter one
function compareScene(unit, caption) {
  const PAD = 16, GAP = 12, LABEL = 16, TOP = 52, Z = 1.25;
  const colW = Math.max(300, ...data.styles.map(st => data.cards[st][unit].w + 8));
  const heights = [TOP, TOP];
  let cells = '';
  for (const style of data.styles) {
    const c = data.cards[style][unit], look = cardHTML(c), now = style === 'regular';
    const col = heights[0] <= heights[1] ? 0 : 1, x = PAD + col * (colW + GAP), y = heights[col];
    cells += `<div class="t" style="left:${x + 4}px;top:${y + 2}px;font-size:12px;color:${now ? C.gold : C.dim}">${esc(data.labels[style])}${now ? '  (in use)' : ''}<span style="font-size:10px;color:${C.faint};margin-left:8px">${esc(data.hints[style])}</span></div>
      <div style="position:absolute;left:${x + 4}px;top:${y + LABEL + 10}px">${look.html}</div>`;
    heights[col] += LABEL + 10 + c.h + 8 + GAP;
  }
  const W = colW * 2 + PAD * 2 + GAP, H = Math.max(...heights) + PAD - GAP;
  const showing = unit === 'wolf' ? 'Showing a sample wolf. Hover any creature or player to see it in every look.'
    : 'Showing the unit you hovered last. Hover another to compare.';
  const win = `<div style="position:relative;width:${W}px;height:${H}px">
    <div class="dialog" style="left:-7px;top:-7px;width:${W + 14}px;height:${H + 14}px"></div>
    <div style="position:absolute;left:2px;right:2px;top:2px;height:26px;background:rgba(0,0,0,.45)"></div>
    <div class="t title" style="left:${PAD}px;top:5px;font-size:19px;color:${C.gold}">Krakentip</div>
    <div class="t" style="left:${PAD + 92}px;top:11px;font-size:11px;color:${C.dim}">every look side by side. Click one to use it.</div>
    <div class="t" style="right:8px;top:4px;font-size:16px;color:${C.dim};font-weight:700">✕</div>
    <div class="t" style="left:${PAD}px;top:32px;font-size:12px">${showing}</div>
    ${cells}</div>`;
  return scene(W * Z + 60, H * Z + 90, at(30, 30, win, Z), caption);
}

// the same looks at other sizes, and the bar's textures and colours
function variantsScene() {
  const V = data.variants, Z = 1.4;
  let inner = '', y = 30;
  const row = (label, c, x) => `<div class="label" style="left:${x}px;top:${y}px">${label}</div>${at(x, y + 32, cardHTML(c).html, Z)}`;
  inner += row('Regular, as designed', V.regular, 40) + row('Width 80%, height 70%', V.regularSmall, 420);
  y += Math.max(V.regular.h, V.regularSmall.h) * Z + 60;
  inner += row('Regular, width 130%, height 120%', V.regularWide, 40) + row('Minimal, width 160%, height 130%', V.minimalWide, 520);
  y += Math.max(V.regularWide.h, V.minimalWide.h) * Z + 60;
  const keys = Object.keys(data.barLabels);
  keys.forEach((k, i) => {
    const x = 40 + (i % 4) * 230, yy = y + Math.floor(i / 4) * (V[k].h * Z + 44);
    const what = k.startsWith('tex_') ? 'Texture: ' : 'Colour: ';
    inner += `<div class="label" style="left:${x}px;top:${yy}px">${what}${esc(data.barLabels[k])}</div>${at(x, yy + 22, cardHTML(V[k]).html, 1)}`;
  });
  const bottom = y + Math.ceil(keys.length / 4) * (V[keys[0]].h * Z + 44) + 30;
  return scene(980, bottom, inner, 'Every look can be wider, narrower, taller or lower, and the bar can change its texture and colour.');
}

function spotScene() {
  const c = card('regular', 'wolf'), s = 1.15;
  return scene(900, 500, `${creature(250, 220, 'Timberling Ravager', '#ff4d40', 62, 1.2)}
    <div class="cursor" style="left:390px;top:270px"></div>
    ${at(900 - 30 - c.w * s, 500 - 50 - c.h * s, c.html, s)}`,
    '<span style="position:absolute;left:24px">Or where the game puts tooltips (move that in Edit Mode). Action targeting puts its card there too.</span>');
}

function pairScene() {
  const a = card('regular', 'boss'), b = card('regular', 'boar');
  return scene(900, 400, at(60, 50, a.html, SCALE) + at(900 - 60 - b.w * SCALE, 50, b.html, SCALE),
    'A boss gets a skull (its health hidden here, so just the bar). A neutral creature gets a yellow name.');
}

// a party member somewhere else, and a wolf the whole group needs
function groupScene() {
  const G = data.group, Z = 1.35, order = data.styles;
  let inner = '', y = 26;
  inner += `<div class="label" style="left:40px;top:${y}px">Jokke, in your party, in another zone</div>
    <div class="label" style="left:520px;top:${y}px">A wolf you and Jokke both need</div>`;
  y += 34;
  for (const st of order) {
    const m = cardHTML(G[st].member), w = cardHTML(G[st].wolf);
    inner += `<div class="t" style="left:40px;top:${y - 2}px;font-size:12px;color:${C.dim}">${esc(data.labels[st])}</div>`;
    inner += at(40, y + 24, m.html, Z) + at(520, y + 24, w.html, Z);
    y += Math.max(m.h, w.h) * Z + 54;
  }
  return scene(1000, y + 20, inner, "The zone and \"Skinnable\" come from the game's tooltip; each member's quest progress shows under their name.");
}

// ---------------------------------------------------------------- the options window (Options.lua)
const OW = 360, OP = 18;
function optionsHTML(o) {
  const OH = o.frameHeight;
  let s = `<div class="dialog" style="left:-7px;top:-7px;width:${OW + 14}px;height:${OH + 14}px"></div>
    <div style="position:absolute;left:2px;right:2px;top:2px;height:26px;background:rgba(0,0,0,.45)"></div>
    <div class="t title" style="left:${OP}px;top:5px;font-size:19px;color:${C.gold}">Krakentip</div>
    <div class="t" style="left:${OP + 92}px;top:11px;font-size:11px;color:${C.dim}">a card for every creature and player</div>
    <div class="t" style="right:8px;top:4px;font-size:16px;color:${C.dim};font-weight:700">✕</div>`;
  const heading = (text, y) => `<div class="t" style="left:${OP}px;top:${y}px;font-size:13px;color:${C.gold}">${text}</div>
    <div style="position:absolute;left:${OP}px;right:${OP}px;top:${y + 17}px;height:1px;background:rgba(255,209,0,.22)"></div>`;
  const stepper = (label, x, y, value, w, arrows) => `<div class="t" style="left:${x}px;top:${y + 4}px;font-size:12px">${label}</div>
    <div class="t" style="left:${x + 58}px;top:${y + 1}px;font-size:15px;color:${C.dim}">${arrows ? '&lt;' : '−'}</div>
    <div class="t" style="left:${x + 76}px;width:${w}px;text-align:center;top:${y + 4}px;font-size:12px;color:${C.gold}">${esc(value)}</div>
    <div class="t" style="left:${x + 82 + w}px;top:${y + 1}px;font-size:15px;color:${C.dim}">${arrows ? '&gt;' : '+'}</div>`;
  let y = 40;
  s += heading('Where the card shows', y); y += 26;
  for (const [label, hint, on] of o.position) {
    s += `<div class="radio ${on ? 'on' : ''}" style="left:${OP}px;top:${y}px"></div>
      <div class="t" style="left:${OP + 22}px;top:${y + 1}px;font-size:12px">${esc(label)}</div>
      <div class="t" style="left:${OP + 22}px;top:${y + 17}px;font-size:11px;color:${C.dim}">${esc(hint)}</div>`;
    y += 36;
  }
  y += 8;
  s += heading('Style', y); y += 26;
  s += `<div class="t" style="left:${OP + 2}px;top:${y + 1}px;font-size:15px;color:${C.dim}">&lt;</div>
    <div class="t" style="left:${OP + 22}px;width:110px;text-align:center;top:${y + 3}px;font-size:13px;color:${C.gold}">${esc(o.styleName)}</div>
    <div class="t" style="left:${OP + 138}px;top:${y + 1}px;font-size:15px;color:${C.dim}">&gt;</div>
    <div class="btn" style="right:${OP}px;top:${y}px;width:130px;height:22px;line-height:20px">Compare all</div>
    <div class="t" style="left:${OP + 2}px;top:${y + 26}px;font-size:11px;color:${C.dim}">${esc(o.styleHint)}</div>`;
  y += 46;
  s += stepper('Width', OP + 2, y, o.width, 44) + stepper('Height', OP + 170, y, o.height, 44);
  y += 30;
  s += heading('Health bar', y); y += 26;
  s += stepper('Texture', OP + 2, y, o.texture, 110, true); y += 26;
  s += stepper('Colour', OP + 2, y, o.color, 110, true); y += 32;
  s += heading(esc(o.fieldsHeading), y) + `<div class="t" style="right:${OP - 6}px;top:${y + 1}px;font-size:11px;color:${C.dim}">Defaults</div>`;
  y += 24;
  // this look's fields in two columns, as Options.lua lays them out
  const half = Math.ceil(o.fieldCount / 2);
  o.checks.slice(0, o.fieldCount).forEach(([label, on], i) => {
    const col = i < half ? 0 : 1, row = i < half ? i : i - half, yy = y + row * 22;
    s += `<div class="check ${on ? 'on' : ''}" style="left:${OP + col * 168}px;top:${yy + 2}px"></div>
      <div class="t" style="left:${OP + 22 + col * 168}px;top:${yy + 3}px;font-size:12px">${esc(label)}</div>`;
  });
  y += half * 22 + 8;
  s += heading('The card', y); y += 24;
  for (const [label, on] of o.checks.slice(o.fieldCount)) {
    s += `<div class="check ${on ? 'on' : ''}" style="left:${OP}px;top:${y + 2}px"></div>
      <div class="t" style="left:${OP + 22}px;top:${y + 3}px;font-size:12px">${esc(label)}</div>`;
    y += 24;
  }
  s += stepper('Scale', OP + 2, y, o.scale, 44); y += 34;
  s += `<div class="btn" style="left:${OP}px;top:${y}px;width:180px">${esc(o.sample)}</div>
    <div class="t" style="left:${OP + 190}px;top:${y + 5}px;font-size:11px;color:${C.dim}">/kt sample does the same</div>`;
  return s;
}

function optionsScene() {
  const c = cardHTML(data.sample), H = data.options.frameHeight + 130;
  return scene(1000, H, `<div style="position:absolute;left:60px;top:50px;width:${OW}px;height:${data.options.frameHeight}px">${optionsHTML(data.options)}</div>
    <div class="cursor" style="left:530px;top:420px"></div>
    ${at(530 + 22 * SCALE, 412 - c.h * SCALE, c.html, SCALE)}`,
    '/kt opens the options. The sample card shows the settings without a creature around.');
}

// ---------------------------------------------------------------- the page
// node tools/screenshots/shots.js --page <file>: every style for every case on
// one page (published as the "Krakentip Cards" artifact), instead of the PNGs.
const pageAt = process.argv.indexOf('--page');
if (pageAt > 0) {
  const file = process.argv[pageAt + 1];
  const version = (fs.readFileSync(path.join(root, 'Krakentip.toc'), 'utf8').match(/## Version: (\S+)/) || [])[1] || '?';
  const commit = (() => { try { return execFileSync('git', ['-C', root, 'rev-parse', '--short', 'HEAD']).toString().trim(); } catch (e) { return ''; } })();
  const built = new Date().toISOString().slice(0, 10);
  const Z = 1.25;
  const fig = (label, hint, c) => {
    const look = cardHTML(c);
    return `<figure class="cell"><figcaption><b>${esc(label)}</b>${hint ? `<span>${esc(hint)}</span>` : ''}</figcaption>
      <div class="stage"><div class="card" style="width:${Math.ceil(look.w * Z) + 24}px;height:${Math.ceil(look.h * Z) + 24}px">
        <div style="position:absolute;left:12px;top:12px;transform:scale(${Z});transform-origin:top left">${look.html}</div></div></div></figure>`;
  };
  const allStyles = (pick) => data.styles.map(st => fig(data.labels[st], data.hints[st], pick(st))).join('');
  const sections = [
    ['wolf', 'A quest creature attacking you', 'Timberling Ravager, level 24 elite wolf. It\'s attacking you, and your quest needs 3 of 8 of its pelts.', allStyles(st => data.cards[st].wolf)],
    ['party', 'The same wolf, with a full party on the quest', 'You and four party members, all on "Ravaged Pelts": you have 3/8, Jokke 5/8, Thalianne 8/8, Mira 1/8, Brokk 6/8.', allStyles(st => data.party[st])],
    ['member', 'A party member in another zone', 'Jokke, an Orc Rogue in your party, standing in Orgrimmar while you\'re elsewhere. The game\'s tooltip adds his zone.', allStyles(st => data.group[st].member)],
    ['boss', 'A boss whose health the game hides', 'Edwin VanCleef. The game hides his health numbers from addons, so the bar fills and the percentage is written by the game.', allStyles(st => data.cards[st].boss)],
    ['neutral', 'A neutral creature', 'Bristleback Quilboar, level 19, neutral (yellow), not attacking anyone.', allStyles(st => data.cards[st].boar)],
    ['npc', 'A friendly NPC', 'Innkeeper Farley, with his title.', allStyles(st => data.cards[st].innkeeper)],
    ['player', 'A friendly player', 'Thalianne, a Night Elf Mage in the guild Krakenhood.', allStyles(st => data.cards[st].friend)],
    ['sizes', 'Width, height and the health bar', 'Each style has its own width and height (60% to 160%). The bar has four textures and three colours.',
      [['Regular as designed', data.variants.regular], ['Regular at width 80%, height 70%', data.variants.regularSmall],
       ['Regular at width 130%, height 120%', data.variants.regularWide], ['Minimal at width 160%, height 130%', data.variants.minimalWide]]
        .map(([l, c]) => fig(l, '', c)).join('') +
      Object.keys(data.barLabels).map(k => fig((k.startsWith('tex_') ? 'Bar texture: ' : 'Bar colour: ') + data.barLabels[k], 'on Mid', data.variants[k])).join('')],
  ];
  const nav = sections.map(([id, title]) => `<a href="#${id}">${esc(title)}</a>`).join('');
  const body = sections.map(([id, title, text, cells]) => `<section id="${id}"><h2>${esc(title)}</h2><p class="lede">${esc(text)}</p><div class="grid">${cells}</div></section>`).join('');
  const PAGE_CSS = `
:root { --ground: #17130f; --panel: #221c16; --line: #4a3c26; --gold: #ffd100; --ink: #efe6d2; --muted: #b3a68b; --faint: #7d725e;
  --display: 'Caladea', 'Bitstream Charter', Georgia, serif; --body: 'Carlito', 'Liberation Sans', Calibri, sans-serif; color-scheme: dark; }
html, body { background: var(--ground); color: var(--ink); }
body { font-family: var(--body); font-size: 15px; line-height: 1.5; }
.wrap { max-width: 1180px; margin: 0 auto; padding-block: 28px 56px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
header { display: grid; gap: 8px; padding-bottom: 20px; border-bottom: 1px solid var(--line); }
header h1 { font-family: var(--display); font-weight: 700; font-size: 34px; color: var(--gold); letter-spacing: .5px; text-wrap: balance; }
header p { color: var(--muted); max-width: 68ch; }
.meta { font-size: 13px; color: var(--faint); font-variant-numeric: tabular-nums; }
nav { display: flex; flex-wrap: wrap; gap: 6px 14px; padding-block: 14px; border-bottom: 1px solid var(--line); }
nav a { color: var(--muted); text-decoration: none; font-size: 14px; }
nav a:hover, nav a:focus-visible { color: var(--gold); text-decoration: underline; outline: none; }
section { padding-top: 34px; display: grid; gap: 8px; }
section h2 { font-family: var(--display); font-size: 24px; color: var(--gold); text-wrap: balance; }
.lede { color: var(--muted); max-width: 70ch; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 460px), 1fr)); gap: 18px 22px; padding-top: 10px; }
.cell { display: grid; gap: 6px; align-content: start; min-width: 0; }
figcaption { display: flex; flex-wrap: wrap; gap: 2px 10px; align-items: baseline; }
figcaption b { font-family: var(--display); font-size: 17px; color: var(--ink); font-weight: 700; }
figcaption span { font-size: 13px; color: var(--faint); }
.stage { overflow-x: auto; border-radius: 4px;
  background: radial-gradient(ellipse at 40% 120%, #3e4a2a 0%, #222c1f 45%, #121a14 100%); }
.stage .card { position: relative; }
footer { margin-top: 44px; padding-top: 16px; border-top: 1px solid var(--line); color: var(--faint); font-size: 13px; max-width: 80ch; }
@media (prefers-reduced-motion: reduce) { * { scroll-behavior: auto; } }
`;
  const html = `<title>Krakentip Cards</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Caladea:wght@400;700&family=Carlito:wght@400;700&display=swap">
<style>${CSS}${PAGE_CSS}</style>
<div class="wrap">
<header><h1>Krakentip cards</h1>
<p>Every card style for the same set of creatures and players, so the styles can be compared side by side. The cards are drawn from the addon's own code; the fonts, textures and the unit portraits are stand-ins for the game's.</p>
<p class="meta">Krakentip ${esc(version)}${commit ? ` · commit ${esc(commit)}` : ''} · built ${built}</p></header>
<nav aria-label="Cases">${nav}</nav>
${body}
<footer>Defaults shown: every field on, except the guild on the small styles (Minimal, Plate, Bar, Icons). Each style's fields, width and height can be changed in the addon's options (/kt). The level's colour says how hard a creature is: grey trivial, green easy, yellow even, orange hard, red very hard.</footer>
</div>`;
  fs.writeFileSync(file, html);
  console.log('wrote', file);
  process.exit(0);
}

// ---------------------------------------------------------------- photograph
const scenes = [
  ['1-card-at-mouse', mouseScene()],
  ['2-compare-creature', compareScene('wolf', '/kt compare: all eight looks side by side, here with the sample wolf.')],
  ['3-compare-player', compareScene('friend', 'Hover any unit while Compare is open, and every look shows it: here a friendly player.')],
  ['4-sizes-and-bars', variantsScene()],
  ['5-card-tooltip-spot', spotScene()],
  ['6-boss-and-neutral', pairScene()],
  ['7-options', optionsScene()],
  ['8-group', groupScene()],
];
fs.mkdirSync(out, { recursive: true });
for (const f of fs.readdirSync(out)) if (f.endsWith('.png')) fs.unlinkSync(path.join(out, f));
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
