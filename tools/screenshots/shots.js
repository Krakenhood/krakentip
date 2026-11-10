// node tools/screenshots/shots.js            redraws assets/screenshots/
// node tools/screenshots/shots.js --page F   writes every look for every case on one page (docs/cards.html)
//
// Hovers the concept page's units headless in each look (shots.lua on
// tests/mock.lua), then draws each card from its parts, where Slate.lua put
// them, with the addon's own textures (media/, as PNG in ./media). The fonts
// are stand-ins for the game's: Marcellus for the names, Alegreya Sans for
// the rest, as on the concept page (docs/clean-slate.html). In the game the
// card is in the game's own font.
const fs = require('fs'), path = require('path');
const { execFileSync } = require('child_process');
const { lua, lauxlib, lualib, to_luastring } = require(path.join(__dirname, '../../tests/node_modules/fengari'));

const root = path.join(__dirname, '../..');
const out = path.join(root, 'assets/screenshots');

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

// ---------------------------------------------------------------- the addon's textures
const MEDIA = {};
for (const f of fs.readdirSync(path.join(__dirname, 'media'))) {
  MEDIA[f.replace(/\.png$/, '')] = 'data:image/png;base64,' + fs.readFileSync(path.join(__dirname, 'media', f)).toString('base64');
}
// a texture: as drawn, or (white ones) tinted
function texBox(name, w, h, tint, extra = '') {
  const url = MEDIA[name];
  if (!url) return '';
  if (tint) {
    const c = `rgba(${tint.slice(0, 3).map(v => Math.round(v * 255)).join(',')},${tint[3] ?? 1})`;
    return `<span style="display:inline-block;width:${w}px;height:${h}px;background:${c};-webkit-mask:url(${url}) 0 0/100% 100% no-repeat;mask:url(${url}) 0 0/100% 100% no-repeat;${extra}"></span>`;
  }
  return `<span style="display:inline-block;width:${w}px;height:${h}px;background:url(${url}) 0 0/100% 100% no-repeat;${extra}"></span>`;
}

// stand-ins for the game's own icons (its skull, gossip and item icons)
const SKULL = (size, color = '#ff2a2a') => `<svg width="${size}" height="${size}" viewBox="0 0 16 16"><path fill="${color}" d="M8 1.4C4.6 1.4 2.4 3.8 2.4 6.7c0 1.8.9 3.1 2.1 3.8v2.1c0 .6.4 1 1 1h.7v-1.4h1.1v1.4h1.4v-1.4h1.1v1.4h.7c.6 0 1-.4 1-1v-2.1c1.2-.7 2.1-2 2.1-3.8 0-2.9-2.2-5.3-5.6-5.3z"/><circle cx="5.9" cy="7.1" r="1.45" fill="#07081a"/><circle cx="10.1" cy="7.1" r="1.45" fill="#07081a"/></svg>`;
const GAME_ICON = {
  BinderGossipIcon: `<svg viewBox="0 0 16 16"><path fill="#d9a441" d="M3 4h7v9H3z"/><path fill="none" stroke="#d9a441" stroke-width="1.6" d="M10 6h2a1.6 1.6 0 0 1 0 3.2h-2"/><path fill="#fff4d6" d="M3 3.2h7V5H3z"/></svg>`,
  INV_Misc_Rune_01: `<svg viewBox="0 0 16 16"><ellipse cx="8" cy="8.5" rx="5.5" ry="6" fill="#7fb5d9"/><path d="M5.5 6.5h5M5.5 9h5" stroke="#1c3a52" stroke-width="1.2"/></svg>`,
  INV_Misc_Food_15: `<svg viewBox="0 0 16 16"><circle cx="8" cy="9" r="5.5" fill="#c8823b"/><path d="M5 7.5c1-1 5-1 6 0" stroke="#f2d39b" stroke-width="1.2" fill="none"/></svg>`,
};
const gameIcon = (file, size) => {
  const key = String(file || '').split('\\').pop();
  const svg = GAME_ICON[key] || `<svg viewBox="0 0 16 16"><circle cx="8" cy="8" r="6" fill="#b49a6a"/></svg>`;
  return `<span style="display:inline-block;width:${size}px;height:${size}px;vertical-align:-2px">${svg.replace('<svg ', `<svg width="${size}" height="${size}" `)}</span>`;
};

// ---------------------------------------------------------------- text as the game writes it
const rgb = c => c ? `rgb(${c.slice(0, 3).map(v => Math.round(v * 255)).join(',')})` : '#fff';
const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;');
// colour codes as spans, inline textures (|T...|t) as the icon they are
function codes(s) {
  let html = '';
  const re = /\|T([^|]*)\|t|\|c[0-9a-f]{2}([0-9a-f]{6})|\|r/gi;
  let last = 0, m, open = 0;
  while ((m = re.exec(s))) {
    html += esc(s.slice(last, m.index));
    if (m[1] !== undefined) {
      const f = m[1].split(':'), file = f[0], h = +f[1] || 12, w = +f[2] || h;
      const media = file.match(/media\\(.+)\.tga$/i);
      if (media) {
        const tint = f.length >= 14 ? [f[11] / 255, f[12] / 255, f[13] / 255] : null;
        html += texBox(media[1], w, h, tint, 'vertical-align:-2px');
      } else {
        html += gameIcon(file, h);
      }
    } else if (m[2]) {
      html += `<span style="color:#${m[2]}">`; open++;
    } else if (open) {
      html += '</span>'; open--;
    }
    last = re.lastIndex;
  }
  return html + esc(s.slice(last)) + '</span>'.repeat(open);
}

// ---------------------------------------------------------------- a card, part by part
const SHIFT = { TOPLEFT: '', TOPRIGHT: 'transform:translateX(-100%);', TOP: 'transform:translateX(-50%);' };
const GLOSS = 'linear-gradient(rgba(255,255,255,.22), rgba(0,0,0,.28))';
const BAR_SHINE = {
  slate: GLOSS,
  smooth: 'linear-gradient(180deg, rgba(255,255,255,.22), rgba(255,255,255,0) 45%, rgba(0,0,0,.28))',
  flat: 'linear-gradient(transparent, transparent)',
  raid: 'linear-gradient(180deg, rgba(255,255,255,.08), rgba(255,255,255,.3) 50%, rgba(0,0,0,.2))',
  skill: 'repeating-linear-gradient(90deg, rgba(0,0,0,.18) 0 1px, transparent 1px 6px), linear-gradient(180deg, rgba(255,255,255,.35), rgba(0,0,0,.35))',
};

function drawPart(p) {
  const pos = `left:${p.x}px;top:${p.y}px;`;
  const shift = SHIFT[p.point] || '';
  switch (p.kind) {
    case 'text': {
      const w = p.width ? `width:${p.width}px;overflow:hidden;text-overflow:ellipsis;` : '';
      const align = p.justify === 'CENTER' ? 'text-align:center;' : p.justify === 'RIGHT' ? 'text-align:right;' : '';
      const font = p.display ? 'font-family:var(--name);' : '';
      const outl = p.outline ? 'text-shadow:-1px -1px 0 #000,1px -1px 0 #000,-1px 1px 0 #000,1px 1px 0 #000;font-weight:700;' : '';
      return `<div class="t" style="${pos}${shift}${w}${align}${font}${outl}font-size:${p.size}px;color:${rgb(p.color)}">${codes(p.text)}</div>`;
    }
    case 'solid':
      return `<div style="position:absolute;${pos}${shift}width:${p.w}px;height:${p.h}px;background:rgba(${p.rgba.slice(0, 3).map(v => Math.round(v * 255)).join(',')},${p.rgba[3]})"></div>`;
    case 'bar': {
      const edge = p.edge ? `box-shadow:0 0 0 1px ${rgb(p.edge)};` : '';
      return `<div style="position:absolute;${pos}${shift}width:${p.w}px;height:${p.h}px;background:#05060c;${edge}">
        <div style="height:100%;width:${(p.fill * 100).toFixed(1)}%;background:${BAR_SHINE[p.texture] || GLOSS}, ${rgb(p.color)}"></div></div>`;
    }
    case 'skull':
      return `<div style="position:absolute;${pos}${shift}line-height:0">${SKULL(p.size)}</div>`;
    case 'tex':
      return `<div style="position:absolute;${pos}${shift}line-height:0;z-index:3">${texBox(p.file, p.w, p.h, p.tint)}</div>`;
    case 'qring': {
      // the track, then the arc as the addon picks it: one of 32 steps
      const step = Math.round(p.frac * 32), i = step - 1, s = p.size;
      const c = p.done ? [0.28, 0.88, 0.31] : [1, 0.82, 0];
      const arc = step > 0 ? `<span style="position:absolute;inset:0;background:${rgb(c)};-webkit-mask:url(${MEDIA['ring-arc']}) ${-(i % 8) * s}px ${-Math.floor(i / 8) * s}px/${8 * s}px ${4 * s}px no-repeat;mask:url(${MEDIA['ring-arc']}) ${-(i % 8) * s}px ${-Math.floor(i / 8) * s}px/${8 * s}px ${4 * s}px no-repeat"></span>` : '';
      return `<div style="position:absolute;${pos}${shift}width:${s}px;height:${s}px;background:url(${MEDIA['ring-track']}) 0 0/100% 100%">${arc}
        <span style="position:absolute;inset:0;display:grid;place-items:center;font-size:${s >= 24 ? 9 : 8}px;font-weight:700;color:#ffe9a0;padding-left:1px">${esc(p.text)}</span></div>`;
    }
    case 'chip':
      return `<div style="position:absolute;${pos}${shift}height:16px;width:${p.w}px;border:1px solid #30354b;background:#0a0b17;display:flex;align-items:center;gap:4px;padding-left:4px;font-size:11px;color:#d9d6cc;white-space:nowrap">${gameIcon(p.icon, 12)}${esc(p.text)}</div>`;
  }
  return '';
}

// the game's tooltip ground, its edge in the rank's colour, and the glow
function cardHTML(c) {
  const glow = c.glow ? `<div class="glow" style="position:absolute;inset:-16px;border:16px solid transparent;border-image:url(${MEDIA.glow}) 16 stretch"></div>` : '';
  const frame = `<div style="position:absolute;inset:-1px;background:rgba(7,8,18,.93);border:1px solid ${rgb(c.edge || [0.44, 0.46, 0.53])};border-radius:3px;
    box-shadow:0 0 0 1px rgba(0,0,0,.85),0 6px 18px rgba(0,0,0,.55)"></div>`;
  return { html: `<div class="tip" style="position:relative;width:${c.w}px;height:${c.h}px">${glow}${frame}${c.parts.map(drawPart).join('')}</div>`, w: c.w, h: c.h };
}

// ---------------------------------------------------------------- the world around a card
const CURSOR = `<svg class="ptr" viewBox="0 0 15 21"><path fill="#d9c08a" stroke="#3b2a12" stroke-width="1.1" stroke-linejoin="round" d="M1.2 1.2v15.6l3.9-3.7 2.9 6.6 2.7-1.2-2.8-6.5h5.4z"/></svg>`;
const BIOME = { wolf: 'forest', party: 'forest', rare: 'forest', boss: 'crypt', inn: 'town', jokke: 'town', tapped: '', enemy: '' };
function stage(style, unit, Z = 1) {
  const c = data.cards[style][unit], look = cardHTML(c), biome = BIOME[unit] || '';
  const scaled = `<div style="width:${Math.ceil(look.w * Z)}px;height:${Math.ceil(look.h * Z)}px"><div style="transform:scale(${Z});transform-origin:top left">${look.html}</div></div>`;
  if (style === 'banner' && c.style === 'banner') {
    const np = data.plates[unit];
    const bar = np.npc ? '' : `<span class="np-bar"><i style="width:${(np.hp * 100).toFixed(0)}%;background:${rgb(np.bar)}"></i></span>`;
    return `<div class="stage plate ${biome}"><div class="np"><span class="np-name out" style="color:${rgb(np.color)}">${esc(np.name.replace(/^Innkeeper /, ''))}</span>${bar}</div>
      <div style="margin-top:9px">${scaled}</div><div class="silhouette"></div></div>`;
  }
  const note = style === 'banner' ? '<p class="fallback">No nameplate to hang from (hovered on the party frame): Glance at the cursor instead.</p>' : '';
  return `<div class="stage cursor ${biome}">${CURSOR}${scaled}${note}</div>`;
}

const CSS = `
:root { --night: #0b0d16; --slate: #141829; --rule: #2a2f47; --parch: #ece6d6; --dust: #a3a2b4; --faint: #6f7089; --gold: #ffd100;
  --title: 'Marcellus', 'Palatino Linotype', Georgia, serif; --body: 'Alegreya Sans', 'Gill Sans', 'Trebuchet MS', sans-serif; --name: var(--title); color-scheme: dark; }
* { box-sizing: border-box; }
html, body { background: var(--night); color: var(--parch); margin: 0; }
body { font-family: var(--body); font-size: 16px; line-height: 1.55; }
.tip { font-family: var(--body); color: #fff; line-height: 1.25; }
.t { position: absolute; white-space: pre; line-height: 1.2; text-shadow: 1px 1px 0 rgba(0,0,0,.85); }
.out { text-shadow: -1px -1px 0 #000, 1px -1px 0 #000, -1px 1px 0 #000, 1px 1px 0 #000; }
.stage { position: relative; border-radius: 4px; overflow: hidden; min-height: 132px;
  background: radial-gradient(120% 90% at 25% 115%, #4b3b22 0%, #2b2418 38%, #151522 74%, #0d0f1a 100%); }
.stage.forest { background: radial-gradient(120% 90% at 30% 115%, #2f4a26 0%, #1d2c1c 40%, #121a1d 75%, #0c1018 100%); }
.stage.town { background: radial-gradient(110% 90% at 70% 110%, #5a3a1d 0%, #33241a 40%, #1a1720 78%, #0e0f18 100%); }
.stage.crypt { background: radial-gradient(120% 90% at 50% 120%, #23314a 0%, #172034 42%, #10131f 78%, #0b0d16 100%); }
.stage.cursor { padding: 30px 10px 22px 28px; }
.stage.cursor > .ptr { position: absolute; left: 9px; top: 8px; width: 15px; height: 21px; }
.stage.plate { display: flex; flex-direction: column; align-items: center; padding: 20px 12px 26px; }
.stage .fallback { font-size: 12.5px; color: var(--dust); margin: 10px 0 0; max-width: 34ch; }
.np { width: 124px; display: grid; gap: 2px; justify-items: center; }
.np-name { font-size: 11.5px; white-space: nowrap; }
.np-bar { width: 124px; height: 8px; border: 1px solid #000; background: #2a0b08; position: relative; }
.np-bar > i { position: absolute; left: 0; top: 0; bottom: 0; }
.silhouette { width: 120px; height: 54px; margin-top: 12px; border-radius: 50% 50% 42% 42%;
  background: radial-gradient(60% 70% at 50% 40%, rgba(60, 50, 44, .9), rgba(20, 17, 15, .0) 72%); }
@media (prefers-reduced-motion: no-preference) {
  .glow { animation: breathe 1.6s ease-in-out infinite alternate; }
  @keyframes breathe { from { opacity: .5; } to { opacity: 1; } }
}
`;
const FONTS = `<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Marcellus&family=Alegreya+Sans:ital,wght@0,400;0,500;0,700;1,400&display=swap">`;

// ---------------------------------------------------------------- the concept page's situations
const SITS = [
  ['wolf', 'A quest creature attacking you', 'Timberling Ravager: elite, three levels above you, needed for your quest, and it is after you. The most urgent tooltip there is.'],
  ['party', 'The same wolf, your whole party on the quest', 'You 3/8, Jokke 5/8, Thalianne 8/8, Mira 1/8, Brokk 6/8. Glance shows a small bar each, the Ledger a short table.'],
  ['tapped', 'Tapped by someone else', 'Another player hit it first, so it is no use to you. Everything goes grey.'],
  ['rare', 'A rare, below your level', 'Silver frame and wing for a rare, a grey level because it is far below you.'],
  ['boss', 'A boss whose health the game hides', 'A skull for the level and a red frame. The bar fills from the game, and the game writes the percentage itself.'],
  ['inn', 'A friendly NPC', 'No health bar: an innkeeper will not lose any. Role and services instead, and the title drops out of the name.'],
  ['jokke', 'A party member in another zone', 'Class colour, guild, faction and where he is. Hovered on the party frame, so the Banner falls back to Glance.'],
  ['enemy', 'An enemy player, flagged for PvP', 'An Alliance rogue: class colour on the edge, the PvP flag, guild and faction, and the red glow because he is after you.'],
];

// ---------------------------------------------------------------- the page
const pageAt = process.argv.indexOf('--page');
if (pageAt > 0) {
  const file = process.argv[pageAt + 1];
  const version = (fs.readFileSync(path.join(root, 'Krakentip.toc'), 'utf8').match(/## Version: (\S+)/) || [])[1] || '?';
  const commit = (() => { try { return execFileSync('git', ['-C', root, 'rev-parse', '--short', 'HEAD']).toString().trim(); } catch (e) { return ''; } })();
  const built = new Date().toISOString().slice(0, 10);
  const cell = (label, html) => `<figure class="cell"><figcaption>${esc(label)}</figcaption>${html}</figure>`;
  const four = data.styles.map(st => `<article class="style"><h3>${esc(data.labels[st])}</h3><p class="tag">${esc(data.hints[st])}</p>${stage(st, 'wolf')}</article>`).join('');
  const sits = SITS.map(([key, title, text]) => `<section class="sit" id="${key}"><header><h3>${esc(title)}</h3><p>${esc(text)}</p></header>
    <div class="cells">${data.styles.map(st => cell(data.labels[st], stage(st, key))).join('')}</div></section>`).join('');
  const V = data.variants;
  const vcell = (label, c) => cell(label, `<div class="stage cursor forest">${CURSOR}${cardHTML(c).html}</div>`);
  const sizes = [['Glance as designed', V.glance], ['Glance at width 80%, height 70%', V.glanceSmall], ['Glance at width 130%, height 120%', V.glanceWide], ['Ledger at width 80%', V.ledgerNarrow]]
    .map(([l, c]) => vcell(l, c)).join('');
  const bars = Object.keys(data.barLabels).map(k => vcell((k.startsWith('tex_') ? 'Texture: ' : 'Colour: ') + data.barLabels[k], V[k])).join('');
  const PAGE_CSS = `
.wrap { max-width: 1280px; margin: 0 auto; padding-block: 36px 72px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); display: grid; gap: 48px; }
h1, h2, h3 { font-family: var(--title); font-weight: 400; margin: 0; text-wrap: balance; }
p { margin: 0; }
.intro { display: grid; gap: 12px; }
.eyebrow { font-size: 13px; letter-spacing: .14em; text-transform: uppercase; color: var(--faint); }
.intro h1 { font-size: clamp(36px, 6vw, 56px); line-height: 1.05; }
.intro h1 em { font-style: normal; color: var(--gold); }
.intro .lede { font-size: 18px; max-width: 64ch; }
.note { font-size: 14px; color: var(--faint); max-width: 90ch; }
nav { display: flex; flex-wrap: wrap; gap: 6px 16px; }
nav a { color: var(--dust); text-decoration: none; font-size: 14px; }
nav a:hover, nav a:focus-visible { color: var(--gold); text-decoration: underline; outline: none; }
.head h2 { font-size: clamp(26px, 3.6vw, 34px); }
.four { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 270px), 1fr)); gap: 22px; }
.style { display: grid; gap: 10px; align-content: start; min-width: 0; }
.style h3 { font-size: 26px; color: var(--gold); }
.style .tag { font-size: 16px; }
.sits { display: grid; gap: 40px; }
.sit { display: grid; gap: 12px; }
.sit > header { display: grid; gap: 4px; }
.sit h3 { font-size: 22px; }
.sit p { font-size: 15px; color: var(--dust); max-width: 80ch; }
.cells { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 280px), 1fr)); gap: 14px; }
.cells.wide { grid-template-columns: repeat(auto-fill, minmax(min(100%, 380px), 1fr)); }
.cell { margin: 0; display: grid; gap: 6px; align-content: start; min-width: 0; }
.cell figcaption { font-family: var(--title); font-size: 16px; color: var(--dust); }
.stage { overflow-x: auto; }
footer { font-size: 14px; color: var(--faint); border-top: 1px solid var(--rule); padding-top: 18px; max-width: 90ch; }
`;
  const html = `<title>Krakentip Cards</title>
<meta name="claude:viewport-fit-sides" content="cover">
${FONTS}
<style>${CSS}${PAGE_CSS}</style>
<div class="wrap">
<header class="intro">
  <p class="eyebrow">Krakentip ${esc(version)} · as built</p>
  <h1>The four looks, <em>from the addon</em></h1>
  <p class="lede">The same units as on the concept page (Clean Slate, docs/clean-slate.html), drawn from the addon's own layout code and its own textures, so the two pages can be laid side by side.</p>
  <p class="note">Krakentip ${esc(version)}${commit ? ` · commit ${esc(commit)}` : ''} · built ${built}. You are Krakenhood, a level 21 warrior. The fonts are stand-ins: in the game the card is in the game's own font, and the skull and the NPC icons are the game's.</p>
</header>
<nav aria-label="Situations"><a href="#four">The four</a>${SITS.map(([k, t]) => `<a href="#${k}">${esc(t)}</a>`).join('')}<a href="#sizes">Width, height and the bar</a></nav>
<section id="four" class="head" style="display:grid;gap:18px"><h2>The four</h2><div class="four">${four}</div></section>
<section class="head" style="display:grid;gap:18px"><h2>Every situation</h2><div class="sits">${sits}</div></section>
<section id="sizes" class="head" style="display:grid;gap:18px"><h2>Width, height and the bar</h2>
  <p class="note" style="font-size:15px;color:var(--dust)">Each look has its own width and height (60% to 160%). The bar has five textures and three colours; Slate and By health are the defaults.</p>
  <div class="cells wide">${sizes}</div><div class="cells">${bars}</div></section>
<footer>Defaults shown: Glance is the everyday look, holding Shift shows the Ledger, and the Ledger shrinks to Glance in combat. Every field is on in every look; each look's fields, width and height can be changed in the options (/kt). The level's colour says how hard a creature is, as the game's own colours: grey trivial, green easy, yellow even, orange hard, red very hard.</footer>
</div>`;
  fs.writeFileSync(file, html);
  console.log('wrote', file);
  process.exit(0);
}

// ---------------------------------------------------------------- the README's pictures
const SCALE = 1.5; // drawn a bit bigger than life, so it reads in the README
const scaled = (look, Z) => `<div style="width:${Math.ceil(look.w * Z)}px;height:${Math.ceil(look.h * Z)}px"><div style="transform:scale(${Z});transform-origin:top left">${look.html}</div></div>`;
const at = (x, y, html) => `<div style="position:absolute;left:${x}px;top:${y}px">${html}</div>`;
const label = (x, y, text) => `<div style="position:absolute;left:${x}px;top:${y}px;font-family:var(--title);font-size:17px;color:var(--dust)">${esc(text)}</div>`;
const scene = (w, h, inner, cls = 'forest') => ({ w, h, html: `<div class="stage ${cls}" style="width:${w}px;height:${h}px;border-radius:0">${inner}</div>` });

// the card sits 22 right of the cursor and 8 above it (Card.lua)
function mouseScene() {
  const c = cardHTML(data.cards.glance.wolf), cx = 230, cy = 60 + 8 * SCALE + c.h * SCALE;
  return scene(760, Math.ceil(cy + 90), `${at(cx, cy, `<svg width="22" height="30" viewBox="0 0 15 21">${CURSOR.slice(CURSOR.indexOf('<path'), -6)}</svg>`)}
    ${at(cx + 22 * SCALE, 60, scaled(c, SCALE))}
    ${label(24, cy + 50, 'Glance, next to the mouse: it follows the cursor, so your eyes stay on the fight.')}`);
}

// the Banner under a stand-in of the creature's nameplate
function bannerLook(unit, Z) {
  const c = cardHTML(data.cards.banner[unit]), np = data.plates[unit];
  const w = Math.ceil(Math.max(c.w * Z, 124 * Z)), plate = 26 * Z;
  const bar = np.npc ? '' : `<span class="np-bar" style="width:${124 * Z}px;height:${8 * Z}px"><i style="width:${(np.hp * 100).toFixed(0)}%;background:${rgb(np.bar)}"></i></span>`;
  return { w: w / Z, h: c.h + 26 + 9, html: `<div style="width:${w}px;display:grid;justify-items:center">
    <div class="np" style="width:auto"><span class="np-name out" style="font-size:${11.5 * Z}px;color:${rgb(np.color)}">${esc(np.name)}</span>${bar}</div>
    <div style="margin-top:${9 * Z}px">${scaled(c, Z)}</div></div>`, raw: true };
}

// the four looks side by side for one unit
function fourScene(unit, caption, cls) {
  let x = 24, inner = '';
  const looks = data.styles.map(st => [st, st === 'banner' ? bannerLook(unit, SCALE) : cardHTML(data.cards[st][unit])]);
  const H = Math.max(...looks.map(([, l]) => l.h)) * SCALE;
  for (const [st, look] of looks) {
    inner += label(x, 18, data.labels[st]) + at(x, 56, look.raw ? look.html : scaled(look, SCALE));
    x += look.w * SCALE + 40;
  }
  return scene(Math.ceil(x - 16), Math.ceil(H + 110), inner + label(24, H + 76, caption), cls);
}

function rowScene(items, caption, cls) {
  let x = 24, inner = '';
  const looks = items.map(([text, c, unit]) => [text, unit ? bannerLook(unit, SCALE) : cardHTML(c)]);
  const H = Math.max(...looks.map(([, l]) => l.h)) * SCALE;
  for (const [text, look] of looks) {
    inner += label(x, 18, text) + at(x, 56, look.raw ? look.html : scaled(look, SCALE));
    x += look.w * SCALE + 40;
  }
  return scene(Math.ceil(x - 16), Math.ceil(H + 110), inner + label(24, H + 76, caption), cls);
}

// ---------------------------------------------------------------- the options window (Options.lua)
const OW = 360, OP = 18, GOLD = '#ffd100', DIM = '#c7b899';
function optionsHTML(o) {
  const OH = o.frameHeight;
  let s = `<div style="position:absolute;left:-7px;top:-7px;width:${OW + 14}px;height:${OH + 14}px;border:10px solid;border-image:linear-gradient(180deg,#f5d77a,#c99a2e 45%,#7a5714) 1;background:#2c2620;box-shadow:0 0 0 2px #120e09,0 10px 30px rgba(0,0,0,.7)"></div>
    <div style="position:absolute;left:2px;right:2px;top:2px;height:26px;background:rgba(0,0,0,.45)"></div>
    <div class="t" style="left:${OP}px;top:5px;font-family:var(--title);font-size:19px;color:${GOLD}">Krakentip</div>
    <div class="t" style="left:${OP + 92}px;top:11px;font-size:11px;color:${DIM}">a card for every creature and player</div>`;
  const heading = (text, y) => `<div class="t" style="left:${OP}px;top:${y}px;font-size:13px;color:${GOLD}">${text}</div>
    <div style="position:absolute;left:${OP}px;right:${OP}px;top:${y + 17}px;height:1px;background:rgba(255,209,0,.22)"></div>`;
  const box = (on, x, y, round) => `<div style="position:absolute;left:${x}px;top:${y}px;width:16px;height:16px;border:1px solid #8a7a50;background:#1a1612;border-radius:${round ? '50%' : '2px'};display:grid;place-items:center;color:${GOLD};font-size:12px;line-height:1">${on ? (round ? '●' : '✓') : ''}</div>`;
  const stepper = (lbl, x, y, value, w, arrows) => `<div class="t" style="left:${x}px;top:${y + 4}px;font-size:12px">${lbl}</div>
    <div class="t" style="left:${x + 58}px;top:${y + 1}px;font-size:15px;color:${DIM}">${arrows ? '&lt;' : '−'}</div>
    <div class="t" style="left:${x + 76}px;width:${w}px;text-align:center;top:${y + 4}px;font-size:12px;color:${GOLD}">${esc(value)}</div>
    <div class="t" style="left:${x + 82 + w}px;top:${y + 1}px;font-size:15px;color:${DIM}">${arrows ? '&gt;' : '+'}</div>`;
  const btn = (text, x, y, w) => `<div style="position:absolute;left:${x}px;top:${y}px;width:${w}px;height:22px;line-height:20px;text-align:center;font-size:12px;color:${GOLD};background:linear-gradient(#8b1a12,#4a0a06);border:1px solid #c99a2e;border-radius:3px">${esc(text)}</div>`;
  let y = 40;
  s += heading('Where the card shows', y); y += 26;
  for (const [lbl, hint, on] of o.position) {
    s += box(on, OP, y, true) + `<div class="t" style="left:${OP + 22}px;top:${y + 1}px;font-size:12px">${esc(lbl)}</div>
      <div class="t" style="left:${OP + 22}px;top:${y + 17}px;font-size:11px;color:${DIM}">${esc(hint)}</div>`;
    y += 36;
  }
  y += 8;
  s += heading('Style', y); y += 26;
  s += `<div class="t" style="left:${OP + 2}px;top:${y + 1}px;font-size:15px;color:${DIM}">&lt;</div>
    <div class="t" style="left:${OP + 22}px;width:110px;text-align:center;top:${y + 3}px;font-size:13px;color:${GOLD}">${esc(o.styleName)}</div>
    <div class="t" style="left:${OP + 138}px;top:${y + 1}px;font-size:15px;color:${DIM}">&gt;</div>
    ${btn('Compare all', OW - OP - 130, y, 130)}
    <div class="t" style="left:${OP + 2}px;top:${y + 26}px;font-size:11px;color:${DIM}">${esc(o.styleHint)}</div>`;
  y += 46;
  s += stepper('Width', OP + 2, y, o.width, 44) + stepper('Height', OP + 170, y, o.height, 44);
  y += 30;
  s += heading('Health bar', y); y += 26;
  s += stepper('Texture', OP + 2, y, o.texture, 110, true); y += 26;
  s += stepper('Colour', OP + 2, y, o.color, 110, true); y += 32;
  s += heading(esc(o.fieldsHeading), y) + `<div class="t" style="right:${OP - 6}px;top:${y + 1}px;font-size:11px;color:${DIM}">Defaults</div>`;
  y += 24;
  const half = Math.ceil(o.fieldCount / 2);
  o.checks.slice(0, o.fieldCount).forEach(([lbl, on], i) => {
    const col = i < half ? 0 : 1, row = i < half ? i : i - half, yy = y + row * 22;
    s += box(on, OP + col * 168, yy + 2) + `<div class="t" style="left:${OP + 22 + col * 168}px;top:${yy + 3}px;font-size:12px">${esc(lbl)}</div>`;
  });
  y += half * 22 + 8;
  s += heading('The card', y); y += 24;
  const extra = o.checks.slice(o.fieldCount);
  s += box(extra[0][1], OP, y + 2) + `<div class="t" style="left:${OP + 22}px;top:${y + 3}px;font-size:12px">${esc(extra[0][0])}</div>`;
  y += 24;
  extra.slice(1).forEach(([lbl, on], i) => {
    s += box(on, OP + i * 168, y + 2) + `<div class="t" style="left:${OP + 22 + i * 168}px;top:${y + 3}px;font-size:12px">${esc(lbl)}</div>`;
  });
  y += 24;
  s += stepper('Scale', OP + 2, y, o.scale, 44); y += 34;
  s += btn(o.sample, OP, y, 180) + `<div class="t" style="left:${OP + 190}px;top:${y + 5}px;font-size:11px;color:${DIM}">/kt sample does the same</div>`;
  return `<div style="position:relative;width:${OW}px;height:${OH}px">${s}</div>`;
}

function optionsScene() {
  const c = cardHTML(data.sample), H = data.options.frameHeight + 80;
  return scene(1000, H, `${at(50, 40, optionsHTML(data.options))}
    ${at(480, 60, scaled(c, SCALE))}
    <div style="position:absolute;left:480px;top:${Math.ceil(90 + c.h * SCALE)}px;width:440px;font-family:var(--title);font-size:17px;color:var(--dust)">/kt opens the options. The sample card shows the settings without a creature around.</div>`, 'town');
}

function sizesScene() {
  const V = data.variants;
  return rowScene([['Glance', V.glance], ['Width 80%, height 70%', V.glanceSmall], ['Width 130%, height 120%', V.glanceWide]],
    'Every look can be wider, narrower, taller or lower (/kt width, /kt height).');
}

const scenes = [
  ['1-card-at-mouse', mouseScene()],
  ['2-the-four', fourScene('wolf', 'Whisper, Glance, Ledger and Banner, for a quest wolf that is after you.', 'forest')],
  ['3-party', rowScene([['Glance', data.cards.glance.party], ['Ledger', data.cards.ledger.party], ['Banner', data.cards.banner.party, 'party']],
    'Your whole party on the quest: a small bar each in Glance, a short table in the Ledger.', 'forest')],
  ['4-sizes', sizesScene()],
  ['5-situations', rowScene([['Rare', data.cards.glance.rare], ['Boss', data.cards.glance.boss], ['Tapped', data.cards.glance.tapped], ['Innkeeper', data.cards.glance.inn]],
    'A rare (silver), a boss (red, health hidden), one tapped by someone else (grey), and an innkeeper: services instead of a bar.', 'crypt')],
  ['6-players', rowScene([['Enemy player, Ledger', data.cards.ledger.enemy], ['Party member, Glance', data.cards.glance.jokke], ['Party member, Ledger', data.cards.ledger.jokke]],
    'Players: class colour on the edge, guild and faction, the PvP flag; a party member\'s zone.', 'town')],
  ['7-options', optionsScene()],
];

(async () => {
  const { chromium } = require('playwright');
  fs.mkdirSync(out, { recursive: true });
  for (const f of fs.readdirSync(out)) if (f.endsWith('.png')) fs.unlinkSync(path.join(out, f));
  const browser = await chromium.launch();
  for (const [name, sc] of scenes) {
    const page = await browser.newPage({ viewport: { width: sc.w, height: sc.h }, deviceScaleFactor: 1 });
    await page.setContent(`<!doctype html><html><head><meta charset="utf-8">${FONTS}<style>${CSS} .glow{animation:none}</style></head><body>${sc.html}</body></html>`, { waitUntil: 'networkidle' }).catch(() => {});
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: path.join(out, name + '.png'), clip: { x: 0, y: 0, width: sc.w, height: sc.h } });
    await page.close();
    console.log('wrote', path.relative(root, path.join(out, name + '.png')));
  }
  await browser.close();
})();
