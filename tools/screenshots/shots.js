// node tools/screenshots/shots.js
//
// Hovers a few units headless in each style (shots.lua on tests/mock.lua), then
// draws what the card showed as HTML and photographs it with Chromium into
// assets/screenshots/. The layout follows Layouts.lua and Options.lua (sizes,
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
const rgb = c => c ? `rgb(${c.map(v => Math.round(v * 255)).join(',')})` : '#fff';
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
.thin { position: absolute; inset: 0; background: rgba(26,23,20,.94); border: 2px solid rgba(255,209,0,.85); border-radius: 3px;
  box-shadow: inset 0 0 0 1px rgba(0,0,0,.6), 0 4px 12px rgba(0,0,0,.6); }
.title { font-family: 'Caladea', 'Bitstream Charter', serif; text-shadow: 1px 1px 1px #000; }
.t { position: absolute; white-space: pre; text-shadow: 1px -1px 0 rgba(0,0,0,.8); }
.out { text-shadow: -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000; }
.tag { display: inline-block; padding: 0 4px; font-weight: 700; color: #1a1208; background: ${C.gold}; text-shadow: none; }
.caption { position: absolute; left: 0; right: 0; bottom: 12px; text-align: center; font-size: 14px; color: #c7b899; text-shadow: 0 1px 2px #000; }
.label { position: absolute; font-size: 15px; color: ${C.gold}; text-shadow: 0 1px 2px #000; }
.cursor { position: absolute; width: 0; height: 0; border-left: 7px solid transparent; border-right: 7px solid transparent;
  border-bottom: 18px solid #e8d9a8; transform: rotate(-28deg); filter: drop-shadow(0 1px 1px #000); }
.check { position: absolute; width: 16px; height: 16px; border: 1px solid #8a7a50; background: #1a1612; border-radius: 2px; }
.check.on::after { content: ''; position: absolute; left: 4px; top: 0; width: 5px; height: 10px; border: solid ${C.gold}; border-width: 0 3px 3px 0; transform: rotate(40deg); }
.radio { position: absolute; width: 16px; height: 16px; border: 1px solid #8a7a50; background: #1a1612; border-radius: 50%; }
.radio.on::after { content: ''; position: absolute; left: 3px; top: 3px; width: 8px; height: 8px; border-radius: 50%; background: ${C.gold}; }
.btn { position: absolute; height: 24px; line-height: 22px; text-align: center; font-size: 12px; color: ${C.gold};
  background: linear-gradient(#8b1a12, #4a0a06); border: 1px solid #c99a2e; border-radius: 3px; text-shadow: 0 1px 1px #000; }
`;

const barFill = c => {
  const col = c.barColor ? rgb(c.barColor) : '#c71f17';
  return `linear-gradient(180deg, rgba(255,255,255,.18), rgba(0,0,0,.25)), ${col}`;
};
function bar(c, x, y, w, h, size, text = true) {
  return `<div style="position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${h}px;background:rgba(0,0,0,.65);box-shadow:0 0 0 1px rgba(255,209,0,.5)">
    <div style="height:100%;width:${Math.round(c.fill * 100)}%;background:${barFill(c)}"></div></div>
    ${text ? `<div class="t out" style="left:${x}px;width:${w}px;top:${y + (h - size) / 2 - 1}px;text-align:center;font-size:${size}px;line-height:${size + 2}px;font-weight:700">${esc(c.hp)}</div>` : ''}`;
}
const skull = size => `<span style="font-size:${size}px;line-height:1">💀</span>`;

// ---------------------------------------------------------------- Regular (Layouts.regular)
function regularHTML(c) {
  const W = c.width, H = c.height, PAD = 8, HEAD = 42;
  let s = `<div class="dialog" style="left:-7px;top:-7px;width:${W + 14}px;height:${H + 14}px"></div>
    <div style="position:absolute;left:2px;right:2px;top:2px;height:${HEAD}px;background:rgba(0,0,0,.45)"></div>
    <div style="position:absolute;left:${PAD}px;top:7px;width:30px;height:30px;border-radius:50%;border:2px solid #c99a2e;
      background:radial-gradient(circle at 40% 35%,#3a2a20,#120c08);display:flex;align-items:center;justify-content:center;box-shadow:0 0 0 1px #000">
      ${c.skull ? skull(15) : `<span class="out" style="font-size:12px;font-weight:700;color:${rgb(c.levelColor)}">${c.level}</span>`}</div>
    <div class="t title" style="left:${PAD + 37}px;top:6px;font-size:16px;color:${rgb(c.nameColor)}">${esc(c.name)}</div>
    <div class="t" style="left:${PAD + 37}px;top:25px;font-size:11px;color:${C.dim}">${esc(c.sub)}${c.tag ? ` <span class="tag" style="margin-left:3px;height:12px;line-height:12px;font-size:9px;vertical-align:1px">${esc(c.tag)}</span>` : ''}</div>
    ${bar(c, PAD, HEAD + 6, W - PAD * 2, 16, 11)}`;
  let y = HEAD + 6 + 16 + 5;
  for (const [label, value, color] of c.rows) {
    s += `<div class="t" style="left:${PAD}px;top:${y + 1}px;font-size:11px;color:${C.dim}">${esc(label)}</div>
      <div class="t" style="right:${PAD}px;top:${y + 1}px;font-size:11px;color:${rgb(color)}">${esc(value)}</div>`;
    y += 16;
  }
  if (c.quests.length) {
    y += 4;
    s += `<div style="position:absolute;left:${PAD}px;right:${PAD}px;top:${y}px;height:1px;background:rgba(255,209,0,.22)"></div>`;
    y += 5;
    for (const [text, color] of c.quests) { s += `<div class="t" style="left:${PAD}px;top:${y}px;font-size:11px;color:${rgb(color)}">${esc(text)}</div>`; y += 14; }
  }
  return { html: `<div style="position:relative;width:${W}px;height:${H}px">${s}</div>`, w: W, h: H };
}

// ---------------------------------------------------------------- Mid (Layouts.mid)
function midHTML(c) {
  const W = c.width, H = c.height, PAD = 7;
  const lvl = c.skull ? `<div class="t" style="left:${PAD}px;top:6px">${skull(12)}</div>`
    : `<div class="t out" style="left:${PAD}px;top:7px;font-size:12px;font-weight:700;color:${rgb(c.levelColor)}">${c.level}</div>`;
  const nameX = c.skull ? 24 : PAD + String(c.level).length * 7 + 5;
  let s = `<div class="thin"></div>${lvl}
    <div class="t title" style="left:${nameX}px;top:4px;font-size:14px;color:${rgb(c.nameColor)}">${esc(c.name)}</div>
    ${c.tag ? `<div class="t tag" style="right:${PAD}px;top:7px;height:11px;line-height:11px;font-size:8px">${esc(c.tag)}</div>` : ''}
    <div class="t" style="left:${PAD}px;top:25px;font-size:10px;color:${C.dim}">${esc(c.sub)}</div>
    ${c.target ? `<div class="t" style="right:${PAD}px;top:25px;font-size:10px;color:${rgb(c.targetColor)}">${esc(c.target)}</div>` : ''}
    ${bar(c, PAD, 40, W - PAD * 2, 9, 9)}`;
  let y = 53;
  for (const [text] of c.quests) { s += `<div class="t" style="left:${PAD}px;top:${y}px;font-size:10px">${esc(text)}</div>`; y += 12; }
  return { html: `<div style="position:relative;width:${W}px;height:${H}px">${s}</div>`, w: W, h: H };
}

// ---------------------------------------------------------------- Minimal (Layouts.minimal)
function minimalHTML(c) {
  const H = 22;
  const lvl = c.skull ? skull(11) : `<span class="out" style="font-size:11px;font-weight:700;color:${rgb(c.levelColor)}">${c.level}</span>`;
  const parts = [lvl, `<span style="font-size:12px;color:${rgb(c.nameColor)}">${esc(c.name)}</span>`];
  if (c.tag) parts.push(`<span class="tag" style="height:11px;line-height:11px;font-size:8px">${esc(c.tag)}</span>`);
  parts.push(`<span style="position:relative;display:inline-block;width:54px;height:8px;background:rgba(0,0,0,.65);box-shadow:0 0 0 1px rgba(255,209,0,.5)"><span style="position:absolute;left:0;top:0;bottom:0;width:${Math.round(c.fill * 100)}%;background:${barFill(c)}"></span></span>`);
  parts.push(`<span class="out" style="font-size:10px;font-weight:700;width:30px;margin-left:-2px">${esc(c.hp)}</span>`);
  if (c.target) parts.push(`<span style="font-size:11px;color:${rgb(c.targetColor)}">${esc(c.target)}</span>`);
  if (c.quest) parts.push(`<span style="font-size:11px;color:${C.gold}">${esc(c.quest)}</span>`);
  return { html: `<div style="position:relative;display:inline-block;height:${H}px"><div class="thin"></div>
    <div style="position:relative;height:${H}px;display:flex;align-items:center;gap:6px;padding:0 6px;white-space:nowrap;text-shadow:1px -1px 0 rgba(0,0,0,.8)">${parts.join('')}</div></div>`, w: 0, h: H };
}

const LOOK = { regular: regularHTML, mid: midHTML, minimal: minimalHTML };
const card = (style, unit) => style === 'sample' ? regularHTML(data.sample) : LOOK[style](data.cards[style][unit]);
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
  const c = card('regular', 'wolf'), cx = 360, cy = 270;
  return scene(900, 500, `${creature(220, 220, 'Timberling Ravager', '#ff4d40', 62, 1.2)}
    <div class="cursor" style="left:${cx}px;top:${cy}px"></div>
    ${at(cx + 22 * SCALE, cy - 8 * SCALE - c.h * SCALE, c.html, SCALE)}`,
    'Regular, next to the mouse: the card follows the cursor, so your eyes stay on the fight.');
}

function stylesScene() {
  const r = card('regular', 'wolf'), m = card('mid', 'wolf'), n = card('minimal', 'wolf');
  const x = 150;
  let y = 40, inner = '';
  inner += `<div class="label" style="left:40px;top:${y + 8}px">Regular</div>${at(x, y, r.html, SCALE)}`;
  y += r.h * SCALE + 40;
  inner += `<div class="label" style="left:40px;top:${y + 8}px">Mid</div>${at(x, y, m.html, SCALE)}`;
  y += m.h * SCALE + 40;
  inner += `<div class="label" style="left:40px;top:${y + 4}px">Minimal</div>${at(x, y, n.html, SCALE)}`;
  return scene(900, y + 22 * SCALE + 70, inner, 'Three looks for the same wolf. Pick one in /kt, or right-click the minimap button to go through them.');
}

function friendsScene() {
  const a = card('regular', 'friend'), b = card('regular', 'innkeeper');
  const c = card('mid', 'friend'), d = card('minimal', 'innkeeper');
  const inner = at(50, 40, a.html, SCALE) + at(470, 40, b.html, SCALE)
    + at(50, 40 + a.h * SCALE + 40, c.html, SCALE) + at(470, 40 + a.h * SCALE + 40, d.html, SCALE);
  return scene(900, 40 + a.h * SCALE + 40 + c.h * SCALE + 70, inner, 'Friends get the card too: players in their class colour with race, class and guild; NPCs with their title.');
}

function spotScene() {
  const c = card('regular', 'wolf'), s = 1.15;
  return scene(900, 500, `${creature(250, 200, 'Timberling Ravager', '#ff4d40', 62, 1.2)}
    <div class="cursor" style="left:390px;top:250px"></div>
    ${at(900 - 30 - c.w * s, 500 - 50 - c.h * s, c.html, s)}`,
    '<span style="position:absolute;left:24px">Or where the game puts tooltips (move that in Edit Mode).</span>');
}

function pairScene() {
  const a = card('regular', 'boss'), b = card('regular', 'boar');
  return scene(900, 400, at(60, 50, a.html, SCALE) + at(900 - 60 - b.w * SCALE, 50, b.html, SCALE),
    'A boss gets a skull (its health hidden here, so just the bar). A neutral creature gets a yellow name.');
}

// ---------------------------------------------------------------- the options window (Options.lua)
const OW = 360, OP = 18;
function optionsHTML(o) {
  const OH = o.height;
  let s = `<div class="dialog" style="left:-7px;top:-7px;width:${OW + 14}px;height:${OH + 14}px"></div>
    <div style="position:absolute;left:2px;right:2px;top:2px;height:26px;background:rgba(0,0,0,.45)"></div>
    <div class="t title" style="left:${OP}px;top:5px;font-size:19px;color:${C.gold}">Krakentip</div>
    <div class="t" style="left:${OP + 92}px;top:11px;font-size:11px;color:${C.dim}">a card for every creature and player</div>
    <div class="t" style="right:8px;top:4px;font-size:16px;color:${C.dim};font-weight:700">✕</div>`;
  const heading = (text, y) => `<div class="t" style="left:${OP}px;top:${y}px;font-size:13px;color:${C.gold}">${text}</div>
    <div style="position:absolute;left:${OP}px;right:${OP}px;top:${y + 17}px;height:1px;background:rgba(255,209,0,.22)"></div>`;
  let y = 40;
  const radios = list => {
    for (const [label, hint, on] of list) {
      s += `<div class="radio ${on ? 'on' : ''}" style="left:${OP}px;top:${y}px"></div>
        <div class="t" style="left:${OP + 22}px;top:${y + 1}px;font-size:12px">${esc(label)}</div>
        <div class="t" style="left:${OP + 22}px;top:${y + 17}px;font-size:11px;color:${C.dim}">${esc(hint)}</div>`;
      y += 36;
    }
  };
  s += heading('Where the card shows', y); y += 26; radios(o.position); y += 8;
  s += heading('Style', y); y += 26; radios(o.style); y += 8;
  s += heading('On the card', y); y += 24;
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
  const c = card('sample'), H = data.options.height + 130;
  return scene(1000, H, `<div style="position:absolute;left:60px;top:50px;width:${OW}px;height:${data.options.height}px">${optionsHTML(data.options)}</div>
    <div class="cursor" style="left:530px;top:400px"></div>
    ${at(530 + 22 * SCALE, 392 - c.h * SCALE, c.html, SCALE)}`,
    '/kt opens the options. The sample card shows the settings without a creature around.');
}

// ---------------------------------------------------------------- photograph
const scenes = [
  ['1-card-at-mouse', mouseScene()],
  ['2-three-styles', stylesScene()],
  ['3-friends-too', friendsScene()],
  ['4-card-tooltip-spot', spotScene()],
  ['5-boss-and-neutral', pairScene()],
  ['6-options', optionsScene()],
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
