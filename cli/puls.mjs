#!/usr/bin/env node
/**
 * Puls CLI v6 — the terminal trading desk.
 *
 *  puls                          launch interactive TUI
 *  puls login <key>              save API key
 *  puls wallet                   wallet & balance
 *  puls markets                  browse live markets
 *  puls market <slug>            deep detail + candlestick
 *  puls search <term>            fuzzy search with ranking
 *  puls watch <slug>             live candlestick tracker
 *  puls compare <a> <b>          side-by-side
 *  puls top                      top by volume
 *  puls feed                     live trade stream
 *  puls oracle <slug>            AI swarm vs crowd
 *  puls stats                    platform dashboard
 *  puls heatmap                  market heat grid
 *  puls history <slug>           price history chart
 *  puls calc <odds> <bet>        bet calculator
 *  puls alert <slug> up|down <¢> set alert
 *  puls alerts                   manage alerts
 *  puls theme [name]             switch theme
 *  puls open <slug>              open in browser
 *  puls doctor                   diagnostics
 *
 *  flags: --json · --no-color · --no-anim · --watch · --compact
 *         --active · --sort vol|odds|new · --limit N · --min N · -v
 */

import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { exec, execSync } from 'node:child_process';
import readline from 'node:readline';

// ═══════════════════════════════════════════════════════════════════
//  CONFIG
// ═══════════════════════════════════════════════════════════════════

const VERSION = '6.1.1';
const API_BASE = (process.env.PULS_API || 'https://api.pulsmarket.tech').replace(/\/+$/, '');
const WEB_BASE = 'https://app.pulsmarket.tech';
const CFG_DIR  = join(homedir(), '.puls');
const CFG_FILE = join(CFG_DIR, 'config.json');
const ALERT_FILE = join(CFG_DIR, 'alerts.json');
const PORTFOLIO_FILE = join(CFG_DIR, 'portfolio.json');

const rawArgs = process.argv.slice(2);
const flag = n => {
  const eq = rawArgs.find(a => a.startsWith(`--${n}=`));
  if (eq) return eq.split('=').slice(1).join('=');
  const i = rawArgs.indexOf(`--${n}`);
  return i >= 0 && i + 1 < rawArgs.length && !rawArgs[i + 1].startsWith('--') ? rawArgs[i + 1] : null;
};
const has = f => rawArgs.includes(f);
const F = {
  json: has('--json'), nc: has('--no-color') || !!process.env.NO_COLOR,
  na: has('--no-anim') || !!process.env.PULS_NO_ANIM,
  watch: has('--watch'), compact: has('--compact'), active: has('--active'),
};
const flagKeys = new Set(['--sort', '--limit', '--min', '--interval']);
const args = rawArgs.filter((a, i) => {
  if (a.startsWith('--') || a === '-v') return false;
  if (i > 0 && flagKeys.has(rawArgs[i - 1])) return false;
  return true;
});

const IS_TTY = process.stdout.isTTY && !F.na;
const TW = (() => { try { return process.stdout.columns || 100; } catch { return 100; } })();
const TH = (() => { try { return process.stdout.rows || 40; } catch { return 40; } })();
const PW = Math.min(TW, 120);

// ═══════════════════════════════════════════════════════════════════
//  THEME ENGINE
// ═══════════════════════════════════════════════════════════════════

const THEMES = {
  puls: {
    name: 'Puls', desc: 'brand pink → mint',
    pal: [[236,72,153],[244,114,182],[180,138,178],[110,170,184],[74,194,189],[45,212,191]],
    ok:[34,197,94], bad:[244,63,94], inf:[45,212,191],
    tx:[226,232,240], br:[248,250,252], dm:[122,134,154], dk:[51,65,85],
    up:[45,212,191], dn:[244,63,94],
  },
  obsidian: {
    name: 'Obsidian', desc: 'warm gold on deep charcoal',
    pal: [[168,142,80],[217,169,55],[245,158,11],[244,63,94],[139,92,246],[56,189,248]],
    ok:[52,211,153], bad:[244,63,94], inf:[56,189,248],
    tx:[222,218,210], br:[252,250,245], dm:[114,110,102], dk:[64,60,54],
    up:[52,211,153], dn:[244,63,94],
  },
  ember: {
    name: 'Ember', desc: 'fiery orange on warm black',
    pal: [[180,90,40],[230,120,30],[255,160,20],[255,70,70],[200,50,130],[255,200,60]],
    ok:[80,210,130], bad:[255,70,70], inf:[255,200,60],
    tx:[235,215,195], br:[255,245,235], dm:[140,115,95], dk:[75,58,45],
    up:[80,210,130], dn:[255,70,70],
  },
  arctic: {
    name: 'Arctic', desc: 'glacial blue on deep navy',
    pal: [[60,130,190],[80,170,230],[110,200,250],[160,225,255],[45,100,160],[30,70,130]],
    ok:[60,220,170], bad:[240,100,100], inf:[110,200,250],
    tx:[200,225,240], br:[235,248,255], dm:[90,115,145], dk:[35,50,70],
    up:[60,220,170], dn:[240,100,100],
  },
  neon: {
    name: 'Neon', desc: 'hot pink and cyan on void black',
    pal: [[255,0,110],[251,86,7],[255,190,11],[0,245,212],[131,56,236],[58,134,255]],
    ok:[0,245,212], bad:[255,0,110], inf:[58,134,255],
    tx:[210,200,220], br:[250,245,255], dm:[100,90,115], dk:[40,35,50],
    up:[0,245,212], dn:[255,0,110],
  },
  terminal: {
    name: 'Terminal', desc: 'phosphor green on black',
    pal: [[20,100,20],[40,160,40],[60,220,60],[80,255,80],[30,130,30],[50,190,50]],
    ok:[60,220,60], bad:[200,255,60], inf:[40,160,40],
    tx:[80,200,80], br:[180,255,180], dm:[30,90,30], dk:[12,35,12],
    up:[60,220,60], dn:[200,255,60],
  },
};

function ensureDir() { if (!existsSync(CFG_DIR)) mkdirSync(CFG_DIR, { recursive: true }); }
function loadJson(p, fb) { try { return JSON.parse(readFileSync(p, 'utf8')); } catch { return fb; } }
function saveJson(p, v) { ensureDir(); writeFileSync(p, JSON.stringify(v, null, 2), { mode: 0o600 }); }
function loadCfg() { return loadJson(CFG_FILE, {}); }
function saveCfg(c) { saveJson(CFG_FILE, c); }
function loadAlerts() { return loadJson(ALERT_FILE, []); }
function saveAlerts(a) { saveJson(ALERT_FILE, a); }
function loadPortfolio() { return loadJson(PORTFOLIO_FILE, { positions: [], history: [] }); }
function savePortfolio(p) { saveJson(PORTFOLIO_FILE, p); }

let T = THEMES[loadCfg().theme] || THEMES.puls;
let P = T.pal;
function applyTheme(name) {
  T = THEMES[name] || THEMES.puls;
  P = T.pal;
  const cfg = loadCfg(); cfg.theme = name; saveCfg(cfg);
}

// ═══════════════════════════════════════════════════════════════════
//  COLOR ENGINE
// ═══════════════════════════════════════════════════════════════════

const ESC = '\x1b[', NO = F.nc;
const RST = NO ? '' : ESC + '0m';
const BD  = NO ? '' : ESC + '1m';
const DIM = NO ? '' : ESC + '2m';
const IT  = NO ? '' : ESC + '3m';
const fg = (r, g, b) => NO ? '' : ESC + `38;2;${r};${g};${b}m`;
const bg = (r, g, b) => NO ? '' : ESC + `48;2;${r};${g};${b}m`;
const CU = n => wr(ESC + n + 'A');
const CL = () => wr(ESC + '2K\r');
const HC = () => IS_TTY && wr(ESC + '?25l');
const SC = () => IS_TTY && wr(ESC + '?25h');
const CLS = () => wr(ESC + '2J' + ESC + 'H');
const MV = (x, y) => wr(ESC + y + ';' + x + 'H');
const ALT_SCREEN = () => wr(ESC + '?1049h');
const MAIN_SCREEN = () => wr(ESC + '?1049l');
const TITLE = t => IS_TTY && wr('\x1b]0;Puls — ' + t + '\x07');
const BEL = () => process.stderr.write('\x07');

const mix = (a, b, t) => Math.round(a + (b - a) * t);
const clp = t => Math.max(0, Math.min(1, t));

function gradColor(t) {
  t = clp(t); const s = t * (P.length - 1), i = Math.min(P.length - 2, Math.floor(s)), f = s - i;
  return [mix(P[i][0], P[i+1][0], f), mix(P[i][1], P[i+1][1], f), mix(P[i][2], P[i+1][2], f)];
}

function grad(text, { glow = null, fadeAfter = 1 } = {}) {
  if (NO) return text;
  const chars = [...text], n = chars.length; let out = '';
  for (let i = 0; i < n; i++) {
    const t = n <= 1 ? 0 : i / (n - 1);
    if (t > fadeAfter) break;
    let [r, g, b] = gradColor(t);
    if (glow !== null) { const d = Math.abs(t - glow); if (d < 0.25) { const k = (1 - d / 0.25) * 0.95; r = mix(r, 255, k); g = mix(g, 255, k); b = mix(b, 255, k); } }
    if (fadeAfter < 1 && fadeAfter - t < 0.08) { const k = Math.max(0, (fadeAfter - t) / 0.08); r = Math.round(r * k); g = Math.round(g * k); b = Math.round(b * k); }
    out += fg(r, g, b) + chars[i];
  }
  return out + RST;
}

const pk = s => fg(...T.pal[1]) + s + RST;
const Pk = s => fg(...T.pal[1]) + BD + s + RST;
const cy = s => fg(...T.inf) + s + RST;
const Cy = s => fg(...T.inf) + BD + s + RST;
const am = s => fg(...T.pal[2]) + s + RST;
const Am = s => fg(...T.pal[2]) + BD + s + RST;
const rs = s => fg(...T.bad) + s + RST;
const Rs = s => fg(...T.bad) + BD + s + RST;
const vt = s => fg(...T.pal[4]) + s + RST;
const Vt = s => fg(...T.pal[4]) + BD + s + RST;
const em = s => fg(...T.ok) + s + RST;
const Em = s => fg(...T.ok) + BD + s + RST;
const tx = s => fg(...T.tx) + s + RST;
const Tx = s => fg(...T.br) + s + RST;
const Wh = s => fg(...T.br) + BD + s + RST;
const dm = s => DIM + fg(...T.dm) + s + RST;
const Dm = s => fg(...T.dm) + s + RST;
const di = s => fg(...T.dk) + s + RST;
const er = s => fg(...T.bad) + s + RST;
const Er = s => fg(...T.bad) + BD + s + RST;
const upC = s => fg(...T.up) + BD + s + RST;
const dnC = s => fg(...T.dn) + BD + s + RST;

const badge = (text, r, g, b) => bg(r,g,b) + fg(10,10,12) + BD + ' ' + text + ' ' + RST;
const badgeOpen     = () => badge('LIVE', ...T.ok);
const badgeClosed   = () => badge('CLOSED', ...T.pal[2]);
const badgeResolved = () => badge('RESOLVED', 82, 78, 72);
function statusBadge(s) { s=(s||'open').toLowerCase(); return s==='open'||s==='active'?badgeOpen():s==='closed'||s==='closing'?badgeClosed():badgeResolved(); }
function probColor(pct) { const c = gradColor(clp(pct/100)); return s => fg(...c) + BD + s + RST; }

// ═══════════════════════════════════════════════════════════════════
//  UTILITIES
// ═══════════════════════════════════════════════════════════════════

const sleep = ms => new Promise(r => setTimeout(r, ms));
const wr = s => process.stdout.write(s);
const ln = (s = '') => console.log(s);
const stripAnsi = s => s.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, '').replace(/\x1b\][^\x07]*?\x07/g, '');
const vlen = s => [...stripAnsi(s)].length;
const padR = (s, w) => { const d = w - vlen(s); return d > 0 ? s + ' '.repeat(d) : s; };
const padL = (s, w) => { const d = w - vlen(s); return d > 0 ? ' '.repeat(d) + s : s; };
const center = (s, w) => { const d = w - vlen(s); if (d <= 0) return s; const l = d >> 1; return ' '.repeat(l) + s + ' '.repeat(d - l); };
const fmt = n => (Number(n) || 0).toLocaleString('en-US');
function abbr(n) {
  n = Number(n) || 0;
  if (n >= 1e9) return (n/1e9).toFixed(1).replace(/\.0$/,'') + 'B';
  if (n >= 1e6) return (n/1e6).toFixed(1).replace(/\.0$/,'') + 'M';
  if (n >= 1e4) return (n/1e3).toFixed(1).replace(/\.0$/,'') + 'K';
  return fmt(n);
}
function timeAgo(d) {
  if (!d) return '';
  const ms = Date.now() - new Date(d).getTime();
  if (ms < 60000) return 'just now';
  if (ms < 3600000) return (ms/60000|0) + 'm ago';
  if (ms < 86400000) return (ms/3600000|0) + 'h ago';
  if (ms < 604800000) return (ms/86400000|0) + 'd ago';
  return new Date(d).toLocaleDateString('en', { month: 'short', day: 'numeric' });
}
function openBrowser(u) { const c = process.platform === 'darwin' ? 'open' : process.platform === 'win32' ? 'start ""' : 'xdg-open'; exec(`${c} "${u}"`, () => {}); }
function prompt(q) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(r => rl.question(q, a => { rl.close(); r(a); }));
}
function copyToClip(text) {
  const cmd = process.platform === 'darwin' ? 'pbcopy' : process.platform === 'win32' ? 'clip' : 'xclip -selection clipboard';
  try { execSync(cmd, { input: text }); return true; } catch { return false; }
}

// ═══════════════════════════════════════════════════════════════════
//  ANIMATION ENGINE
// ═══════════════════════════════════════════════════════════════════

const SPINNERS = {
  dots:  ['⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'],
  arc:   ['◜','◠','◝','◞','◡','◟'],
  grow:  ['▁','▃','▄','▅','▆','▇','█','▇','▆','▅','▄','▃'],
  pulse: ['○','◎','●','◎'],
  wave:  ['⠁','⠂','⠄','⡀','⢀','⠠','⠐','⠈'],
  orbit: ['◐','◓','◑','◒'],
  chase: ['⣾','⣽','⣻','⢿','⡿','⣟','⣯','⣷'],
};

function spinner(label, type = 'dots') {
  if (!IS_TTY) return { stop(){}, finish(){}, update(){} };
  const frames = SPINNERS[type] || SPINNERS.dots;
  let idx = 0, dots = 0, alive = true;
  HC();
  const dotT = setInterval(() => dots = (dots + 1) % 4, 380);
  const iv = setInterval(() => {
    if (!alive) return;
    CL();
    const [r,g,b] = gradColor((idx % 60) / 60);
    wr(`  ${fg(r,g,b)}${frames[idx % frames.length]}${RST} ${Dm(label + '.'.repeat(dots))}`);
    idx++;
  }, 75);
  return {
    stop()   { alive = false; clearInterval(iv); clearInterval(dotT); CL(); SC(); },
    finish(c='✓') { alive = false; clearInterval(iv); clearInterval(dotT); CL(); wr(`  ${Em(c)} ${Dm(label)}\n`); SC(); },
    update(m) { label = m; },
  };
}

async function typeWrite(text, speed = 11) {
  if (!IS_TTY) { wr(text); return; }
  for (const ch of [...text]) {
    wr(ch);
    if (ch === ' ') continue;
    let d = speed;
    if ('.!?'.includes(ch)) d *= 4; else if (',;:'.includes(ch)) d *= 2.5;
    await sleep(d);
  }
}

async function toast(msg, icon, color) {
  if (!IS_TTY) { ln(`  ${icon} ${msg}`); return; }
  const steps = ['○','◌','◎','◉','●'];
  for (const f of steps) { CL(); wr(`  ${color(f)} ${Dm(msg)}`); await sleep(22); }
  CL(); wr(`  ${color(BD + icon + RST)} ${Tx(msg)}\n`);
}
const toastOK  = m => toast(m, '✓', Em);
const toastErr = m => toast(m, '✗', Er);

async function countUp(label, target, { prefix = '', suffix = '', duration = 600, color = Cy } = {}) {
  if (!IS_TTY) { ln(`  ${Dm(label)}  ${color(prefix + fmt(target) + suffix)}`); return; }
  const t0 = Date.now();
  while (true) {
    const t = clp((Date.now() - t0) / duration);
    const ease = 1 - Math.pow(1 - t, 3);
    const val = Math.round(target * ease);
    CL(); wr(`  ${Dm(label)}  ${color(prefix + fmt(val) + suffix)}`);
    if (t >= 1) break;
    await sleep(16);
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CHART ENGINE
// ═══════════════════════════════════════════════════════════════════

const BRAILLE = 0x2800;
const BDOT = [0, 1, 2, 6], RDOT = [3, 4, 5, 7];

function sparkMini(data, w = 16) {
  if (!data || data.length < 2) return di('·'.repeat(w));
  const chars = '▁▂▃▄▅▆▇█', pts = [];
  for (let i = 0; i < w; i++) pts.push(data[Math.round(i / Math.max(1, w - 1) * (data.length - 1))]);
  const lo = Math.min(...pts), hi = Math.max(...pts), r = hi - lo || 1;
  return pts.map((v, i) => {
    const ci = Math.min(chars.length - 1, ((v - lo) / r * chars.length) | 0);
    const c = gradColor(i / Math.max(1, w - 1));
    return fg(...c) + chars[ci];
  }).join('') + RST;
}

function lineChart(data, { w = 55, h = 5, fill = true, axis = true, label = '' } = {}) {
  if (!data || data.length < 2) return [di('  no data')];
  const cols = w, dRows = h * 4;
  const pts = [];
  for (let i = 0; i < cols; i++) pts.push(data[Math.round(i / Math.max(1, cols - 1) * (data.length - 1))]);
  const lo = Math.min(...pts), hi = Math.max(...pts), range = hi - lo || 1;
  const grid = Array.from({ length: cols }, () => new Uint8Array(dRows));
  for (let c = 0; c < cols; c++) {
    const norm = (pts[c] - lo) / range;
    const top = Math.round((1 - norm) * (dRows - 1));
    grid[c][top] = 1;
    if (fill) for (let r = top + 1; r < dRows; r++) grid[c][r] = 1;
  }
  const lines = [];
  if (label) lines.push('  ' + Dm(label));
  for (let row = 0; row < h; row++) {
    let ax = '';
    if (axis) {
      if (row === 0)          ax = padL(String(Math.round(hi)), 8) + ' ┤ ';
      else if (row === h - 1) ax = padL(String(Math.round(lo)), 8) + ' ┤ ';
      else                    ax = '         │ ';
    }
    let bl = '';
    for (let bc = 0; bc < Math.ceil(cols / 2); bc++) {
      let mask = 0;
      const lc = bc * 2;
      if (lc < cols) for (let dr = 0; dr < 4; dr++) if (grid[lc][row * 4 + dr]) mask |= 1 << BDOT[dr];
      const rc = bc * 2 + 1;
      if (rc < cols) for (let dr = 0; dr < 4; dr++) if (grid[rc][row * 4 + dr]) mask |= 1 << RDOT[dr];
      bl += String.fromCodePoint(BRAILLE + mask);
    }
    const rowT = h <= 1 ? 0.4 : 0.15 + (row / (h - 1)) * 0.55;
    lines.push(ax + fg(...gradColor(rowT)) + bl + RST);
  }
  if (axis) lines.push('         └' + '─'.repeat(Math.ceil(cols / 2) + 1));
  return lines;
}

function candlestick(ohlc, { w = 60, h = 8, axis = true, volBars = true } = {}) {
  if (!ohlc || ohlc.length < 2) return [di('  no OHLC data')];
  const N = ohlc.length;
  const volH = volBars ? Math.max(1, Math.floor(h * 0.22)) : 0;
  const chartH = h - volH;
  const pCols = w * 2, pRows = chartH * 4;
  let lo = Infinity, hi = -Infinity;
  for (const c of ohlc) { lo = Math.min(lo, c.low); hi = Math.max(hi, c.high); }
  const pad = (hi - lo) * 0.06 || 1;
  lo -= pad; hi += pad;
  const toRow = price => Math.round((1 - (price - lo) / (hi - lo)) * (pRows - 1));
  const volMax = Math.max(...ohlc.map(c => c.volume || 0)) || 1;
  const gridUp = Array.from({length: pCols}, () => new Uint8Array(pRows));
  const gridDn = Array.from({length: pCols}, () => new Uint8Array(pRows));
  for (let i = 0; i < N; i++) {
    const c = ohlc[i];
    const isUp = c.close >= c.open;
    const g = isUp ? gridUp : gridDn;
    const cx = Math.floor((i + 0.5) * pCols / N);
    const x0 = Math.floor(i * pCols / N);
    const x1 = Math.floor((i + 1) * pCols / N);
    const halfW = Math.max(0, Math.floor((x1 - x0) * 0.35));
    const wt = toRow(c.high), wb = toRow(c.low);
    for (let y = Math.max(0, wt); y <= Math.min(pRows - 1, wb); y++) g[cx][y] = 1;
    const bt = toRow(Math.max(c.open, c.close));
    const bb = toRow(Math.min(c.open, c.close));
    const bodyTop = Math.max(0, bt);
    const bodyBot = Math.min(pRows - 1, bb);
    for (let x = Math.max(0, cx - halfW); x <= Math.min(pCols - 1, cx + halfW); x++) {
      for (let y = bodyTop; y <= bodyBot; y++) g[x][y] = 1;
    }
  }
  const lines = [];
  for (let row = 0; row < chartH; row++) {
    let ax = '';
    if (axis) {
      if (row === 0)              ax = padL('$' + Math.round(hi), 8) + ' ┤ ';
      else if (row === chartH - 1) ax = padL('$' + Math.round(lo), 8) + ' ┤ ';
      else                         ax = '         │ ';
    }
    let line = '';
    for (let bc = 0; bc < w; bc++) {
      let mU = 0, mD = 0;
      for (let dy = 0; dy < 4; dy++) {
        const py = row * 4 + dy;
        const lx = bc * 2, rx = bc * 2 + 1;
        if (lx < pCols) { if (gridUp[lx][py]) mU |= 1 << BDOT[dy]; if (gridDn[lx][py]) mD |= 1 << BDOT[dy]; }
        if (rx < pCols) { if (gridUp[rx][py]) mU |= 1 << RDOT[dy]; if (gridDn[rx][py]) mD |= 1 << RDOT[dy]; }
      }
      if (mD)       line += fg(...T.dn) + String.fromCodePoint(BRAILLE + mD) + RST;
      else if (mU)  line += fg(...T.up) + String.fromCodePoint(BRAILLE + mU) + RST;
      else          line += ' ';
    }
    lines.push(ax + line);
  }
  if (axis) lines.push('         └' + '─'.repeat(w + 1));
  if (volBars && volH > 0) {
    lines.push('');
    for (let row = 0; row < volH; row++) {
      let ax = row === 0 ? '   vol  ┤ ' : '         │ ';
      let line = '';
      for (let i = 0; i < N; i++) {
        const c = ohlc[i];
        const volFrac = (c.volume || 0) / volMax;
        const filled = Math.round(volFrac * volH);
        const thisRow = volH - 1 - row;
        const isUp = c.close >= c.open;
        if (thisRow < filled) line += isUp ? fg(...T.up) + '█' : fg(...T.dn) + '█';
        else line += ' ';
        const candleW = Math.max(1, Math.floor(w / N));
        line += ' '.repeat(Math.max(0, candleW - 1));
      }
      lines.push(ax + line + RST);
    }
  }
  return lines;
}

function probBar(pct, w = 28) {
  const filled = Math.round(pct / 100 * w); let s = '';
  for (let i = 0; i < w; i++) {
    const c = gradColor(i / Math.max(1, w - 1));
    s += i < filled ? fg(...c) + '█' : di('░');
  }
  return s + RST;
}

function hBar(val, max, w = 22, color = cy) {
  const filled = Math.round((val / Math.max(1, max)) * w);
  let s = '';
  for (let i = 0; i < w; i++) s += i < filled ? color('█') : di('░');
  return s;
}

// ═══════════════════════════════════════════════════════════════════
//  UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════

function rule(w = PW) { let s = ''; for (let i = 0; i < w; i++) s += fg(...gradColor(i / Math.max(1, w - 1))) + '─'; return s + RST; }

function header(title, meta = '', icon = '◆') {
  ln('\n  ' + Pk(icon) + '  ' + grad(title) + (meta ? '  ' + Dm(meta) : ''));
  ln('  ' + rule(PW));
}

function card(lines, { title = '', w: innerW = 0, border = 'round' } = {}) {
  const cleanLines = lines.map(stripAnsi);
  const cleanTitle = stripAnsi(title);
  innerW = Math.min(PW + 10, Math.max(innerW, cleanTitle.length + 6, ...cleanLines.map(l => [...l].length)));
  const b = border === 'double' ? ['╔','═','╗','║','╚','╝'] : border === 'heavy' ? ['┏','━','┓','┃','┗','┛'] : ['╭','─','╮','│','╰','╯'];
  const [tl, h, tr, v, bl, br] = b;
  const out = [];
  if (title) {
    const pad = Math.max(0, (innerW - [...cleanTitle].length - 4) / 2 | 0);
    out.push(`  ${Pk(tl)}${Pk(h.repeat(pad + 1))} ${Wh(title)} ${Pk(h.repeat(Math.max(1, innerW - pad - [...cleanTitle].length - 3)))}${Pk(tr)}`);
  } else {
    out.push(`  ${Pk(tl)}${Pk(h.repeat(innerW + 2))}${Pk(tr)}`);
  }
  for (let i = 0; i < lines.length; i++) {
    out.push(`  ${Pk(v)} ${lines[i]}${' '.repeat(Math.max(0, innerW - [...cleanLines[i]].length))} ${Pk(v)}`);
  }
  out.push(`  ${Pk(bl)}${Pk(h.repeat(innerW + 2))}${Pk(br)}`);
  return out.join('\n');
}

function walletCard(d) {
  const addr = d.address || '—';
  const short = addr.length > 20 ? addr.slice(0, 8) + '··' + addr.slice(-6) : addr;
  return card([
    `${Dm('address')}  ${Tx(short)}`,
    `${Dm('balance')} ${Cy('$' + (d.usdcBalance ?? '0') + ' USDC')}`,
  ], { w: 44, title: Wh('PULS') + ' ' + Dm('wallet') });
}


// ═══════════════════════════════════════════════════════════════════
//  FUZZY SEARCH
// ═══════════════════════════════════════════════════════════════════

function fuzzyScore(query, target) {
  query = query.toLowerCase(); target = target.toLowerCase();
  if (target.includes(query)) return 100 + (target.startsWith(query) ? 50 : 0) - target.length * 0.1;
  let qi = 0, score = 0, prev = false;
  for (let ti = 0; ti < target.length && qi < query.length; ti++) {
    if (target[ti] === query[qi]) { score += prev ? 8 : 4; if (ti < 3) score += 6; prev = true; qi++; }
    else prev = false;
  }
  return qi === query.length ? score - target.length * 0.05 : -1;
}

function fuzzyFilter(items, query, getStr) {
  if (!query) return items;
  return items.map(item => ({ item, score: fuzzyScore(query, getStr(item)) }))
    .filter(x => x.score > 0).sort((a, b) => b.score - a.score).map(x => x.item);
}

function fuzzyHighlight(query, text) {
  if (!query) return Tx(text);
  const lq = query.toLowerCase(), lt = text.toLowerCase();
  let qi = 0, out = '';
  for (let i = 0; i < text.length; i++) {
    if (qi < lq.length && lt[i] === lq[qi]) { out += Am(text[i]); qi++; }
    else out += Tx(text[i]);
  }
  return out;
}

// ═══════════════════════════════════════════════════════════════════
//  API LAYER
// ═══════════════════════════════════════════════════════════════════

const _cache = new Map();
const cacheGet = (k, ttl) => { const e = _cache.get(k); return e && Date.now() - e.t < ttl ? e.v : null; };
const cacheSet = (k, v) => _cache.set(k, { v, t: Date.now() });
const cacheClear = () => _cache.clear();

async function api(path, { method = 'GET', body, auth = false, key: ek } = {}) {
  const headers = { accept: 'application/json' };
  if (body) headers['content-type'] = 'application/json';
  if (auth || ek) {
    const k = ek || loadCfg().key;
    if (!k) throw new Error('Not logged in. Run:  puls login pk_live_…');
    headers.authorization = 'Bearer ' + k;
  }
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const resp = await fetch(API_BASE + path, { method, headers, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(15000) });
      const text = await resp.text();
      let data; try { data = JSON.parse(text); } catch { data = text; }
      if (!resp.ok) { if (resp.status >= 500 && attempt < 2) { await sleep(300 * 2**attempt); continue; } throw new Error(data?.error || 'HTTP ' + resp.status); }
      return data;
    } catch (e) {
      if (/TimeoutError|network|ECONNRESET|fetch/i.test(e.message) && attempt < 2) { await sleep(300 * 2**attempt); continue; }
      throw new Error(e.name === 'TimeoutError' ? 'Request timed out' : 'Network: ' + e.message);
    }
  }
}

async function fetchMarkets(limit = 200) {
  const k = 'mk:' + limit, cached = cacheGet(k, 30000);
  if (cached) return cached;
  const d = await api('/api/markets?limit=' + limit);
  const ms = Array.isArray(d) ? d : d.markets || [];
  cacheSet(k, ms); return ms;
}

function jsonOut(d) { if (F.json) { console.log(JSON.stringify(d, null, 2)); return true; } return false; }

async function checkLogin() {
  if (loadCfg().key) return true;
  ln(Er('\n  Not logged in.') + Dm('  Run ') + Pk('puls login pk_live_…'));
  ln(Dm('  Generate a key at ') + cy(WEB_BASE + '/profile/api-keys') + '\n');
  return false;
}

function fakeOHLC(odds, n = 40) {
  const data = [];
  let price = odds ?? 50;
  for (let i = 0; i < n; i++) {
    const move = (Math.random() - 0.48) * 8;
    const open = price;
    const close = Math.max(1, Math.min(99, price + move));
    const high = Math.max(open, close) + Math.random() * 4;
    const low = Math.min(open, close) - Math.random() * 4;
    const volume = Math.round(5000 + Math.random() * 30000);
    data.push({ open, high: Math.min(99, high), low: Math.max(1, low), close, volume });
    price = close;
  }
  return data;
}

// ═══════════════════════════════════════════════════════════════════
//  INTRO
// ═══════════════════════════════════════════════════════════════════

const BANNER = [
  '██████╗ ██╗   ██╗██╗     ███████╗',
  '██╔══██╗██║   ██║██║     ██╔════╝',
  '██████╔╝██║   ██║██║     ███████╗',
  '██╔═══╝ ██║   ██║██║     ╚════██║',
  '██║     ╚██████╔╝███████╗███████║',
  '╚═╝      ╚═════╝ ╚══════╝╚══════╝',
];

async function intro() {
  if (!IS_TTY) { ln(grad(BANNER.join('\n'))); ln(Dm('\n  the market for what happens next\n')); return; }
  HC();
  const totalCols = BANNER[0].length, totalRows = BANNER.length;
  const chars = BANNER.map(l => [...l]);
  const scatter = '·∙⋅∘●○◎◉✦✧⬡░▒▓';

  // Phase 1: scatter resolving into the logo
  for (let frame = 0; frame <= 8; frame++) {
    MV(1, 1);
    const p = frame / 8;
    for (let r = 0; r < totalRows; r++) {
      let row = '';
      for (let c = 0; c < chars[r].length; c++) {
        const [gr, gg, gb] = gradColor(c / Math.max(1, totalCols));
        if (chars[r][c] === ' ') { row += ' '; continue; }
        if (p < 0.8) {
          const ch = scatter[(Math.random() * scatter.length) | 0];
          const a = 0.25 + p * 0.75;
          row += fg(Math.round(gr * a), Math.round(gg * a), Math.round(gb * a)) + ch;
        } else row += fg(gr, gg, gb) + chars[r][c];
      }
      wr(row + RST + '\n');
    }
    if (frame < 8) await sleep(45);
  }

  // Phase 2: glow sweep
  for (let sweep = -4; sweep <= totalCols + 4; sweep += 3) {
    MV(1, 1);
    for (let r = 0; r < totalRows; r++) {
      let row = '';
      for (let c = 0; c < chars[r].length; c++) {
        if (chars[r][c] === ' ') { row += ' '; continue; }
        let [gr, gg, gb] = gradColor(c / Math.max(1, totalCols));
        const dist = Math.abs(c - sweep);
        if (dist < 7) { const k = (1 - dist / 7) * 0.97; gr = mix(gr, 255, k); gg = mix(gg, 255, k); gb = mix(gb, 255, k); }
        row += fg(gr, gg, gb) + chars[r][c];
      }
      wr(row + RST + '\n');
    }
    await sleep(10);
  }

  // Phase 3: final + tagline
  MV(1, 1);
  wr(BANNER.map(line => grad(line)).join('\n') + '\n');
  wr(rule(totalCols) + '\n');
  const tag = '  the market for what happens next';
  const tagArr = [...tag];
  for (let i = 0; i < tagArr.length; i++) {
    const t = i / Math.max(1, tagArr.length - 1);
    wr(fg(...gradColor(t)) + tagArr[i] + RST);
    if (tagArr[i] !== ' ') await sleep(8);
  }
  wr('\n');
  const cfg = loadCfg();
  if (cfg.theme && cfg.theme !== 'puls') wr('  ' + Dm('theme: ') + pk(T.name) + '\n');
  const alerts = loadAlerts();
  if (alerts.length) wr('  ' + Dm(alerts.length + ' price alert' + (alerts.length > 1 ? 's' : '') + ' active') + '\n');
  wr('\n');
  SC();
}


// ═══════════════════════════════════════════════════════════════════
//  INTERACTIVE TUI
// ═══════════════════════════════════════════════════════════════════

async function startTUI() {
  if (!process.stdin.isTTY || !IS_TTY) { ln(Dm('\n  TUI requires an interactive terminal.\n')); help(); return; }
  const cfg = loadCfg();
  if (!cfg.key) {
    ln(`\n  ${Pk('◆')} ${Wh('Welcome to Puls')}\n`);
    ln(`  ${Dm('Save your API key first:')}`);
    ln(`  ${cy(WEB_BASE + '/profile/api-keys')}\n`);
    ln(`  ${Dm('Then:')} ${Pk('puls login pk_live_…')}\n`);
    return;
  }

  const tabs = ['Markets', 'Portfolio', 'Feed', 'Alerts', 'Stats', 'Agents'];
  let tab = 0, sel = 0, markets = [], search = '', searching = false;
  let feedBuf = [], feedSeen = new Set(), sortMode = 'volume';
  let statusMsg = '', statusTimer = null;
  let detailMarket = null, paletteMode = false, paletteQuery = '', paletteSel = 0;
  let scrollOff = 0;
  let loaded = false;
  let agentsData = null;

  function setStatus(msg, ms = 3500) {
    statusMsg = msg; if (statusTimer) clearTimeout(statusTimer);
    statusTimer = setTimeout(() => { statusMsg = ''; render(); }, ms);
  }

  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding('utf8');
  ALT_SCREEN(); HC(); TITLE('interactive mode');

  async function loadData() {
    try {
      markets = await fetchMarkets(200);
      const sorters = {
        volume: (a, b) => (b.volumeUsdc ?? b.volume ?? 0) - (a.volumeUsdc ?? a.volume ?? 0),
        odds:   (a, b) => (b.yesPrice ?? 0.5) - (a.yesPrice ?? 0.5),
        newest: (a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0),
      };
      markets.sort(sorters[sortMode] || sorters.volume);
      if (F.active) markets = markets.filter(m => (m.status || 'open').toLowerCase() === 'open');
    } catch {}
  }

  async function loadFeed() {
    try {
      const list = await api('/api/trade/recent?limit=30');
      for (const t of (Array.isArray(list) ? list : []).reverse()) {
        const id = t.tx_id || t.txId || `${t.question}-${t.usdc_amount}-${t.created_at}`;
        if (!feedSeen.has(id)) { feedSeen.add(id); feedBuf.unshift(t); }
      }
      feedBuf = feedBuf.slice(0, 50);
    } catch {}
  }

  async function loadAgents() {
    try {
      const [house, roster] = await Promise.all([
        api('/api/agents/house').catch(() => null),
        api('/api/agents/roster').catch(() => null),
      ]);
      agentsData = { house, roster };
    } catch {}
  }

  const allActions = [
    { name: 'Refresh markets', key: 'r', fn: async () => { cacheClear(); await Promise.all([loadData(), loadFeed()]); setStatus('Refreshed'); } },
    { name: 'Sort by volume', key: '', fn: () => { sortMode = 'volume'; loadData(); setStatus('Sorted by volume'); } },
    { name: 'Sort by odds', key: '', fn: () => { sortMode = 'odds'; loadData(); setStatus('Sorted by odds'); } },
    { name: 'Sort by newest', key: '', fn: () => { sortMode = 'newest'; loadData(); setStatus('Sorted by newest'); } },
    { name: 'Search markets…', key: '/', fn: () => { searching = true; search = ''; } },
    { name: 'View stats', key: '5', fn: () => { tab = 4; } },
    { name: 'View agents', key: '6', fn: () => { tab = 5; } },
    { name: 'View feed', key: '3', fn: () => { tab = 2; } },
    { name: 'View alerts', key: '4', fn: () => { tab = 3; } },
    { name: 'Theme: Obsidian', key: '', fn: () => { applyTheme('obsidian'); setStatus('Theme: Obsidian'); } },
    { name: 'Theme: Ember', key: '', fn: () => { applyTheme('ember'); setStatus('Theme: Ember'); } },
    { name: 'Theme: Arctic', key: '', fn: () => { applyTheme('arctic'); setStatus('Theme: Arctic'); } },
    { name: 'Theme: Neon', key: '', fn: () => { applyTheme('neon'); setStatus('Theme: Neon'); } },
    { name: 'Theme: Terminal', key: '', fn: () => { applyTheme('terminal'); setStatus('Theme: Terminal'); } },
    { name: 'Quit', key: 'q', fn: () => { quit(); } },
  ];
  function getActions() {
    const marketActions = markets.slice(0, 10).map(m => ({
      name: `Market: ${(m.question || m.slug || '').slice(0, 50)}`, key: '', fn: () => { detailMarket = m; },
    }));
    return [...allActions, ...marketActions];
  }

  function quit() {
    try { process.stdin.setRawMode(false); } catch {}
    process.stdin.pause(); MAIN_SCREEN(); SC(); TITLE('');
    ln(Dm('\n  bye.\n')); process.exit(0);
  }

  function render() {
    const h = TH - 4;
    let buf = ESC + '2J' + ESC + 'H';
    const tabLine = tabs.map((t, i) => i === tab ? Pk(`[${i + 1}]`) + Wh(' ' + t) : di(`[${i + 1}]`) + Dm(' ' + t)).join('    ');
    buf += `  ${grad('PULS')}  ${di('v' + VERSION)}  ${di('│')}  ${tabLine}  ${di('│')}  ${dm(T.name)}\n`;
    buf += '  ' + rule(TW - 4) + '\n';

    if (tab === 0) {
      const sortLabel = `${Dm('sort:')} ${sortMode === 'volume' ? Pk('▼vol') : Dm('vol')}  ${sortMode === 'odds' ? Pk('▼odds') : Dm('odds')}  ${sortMode === 'newest' ? Pk('▼new') : Dm('new')}  ${searching ? Pk('/' + search + '█') : Dm('/ search')}`;
      buf += '  ' + sortLabel + '\n\n';
      const filtered = search ? fuzzyFilter(markets, search, m => (m.question || '') + ' ' + (m.slug || '')) : markets;
      const maxVisible = Math.max(1, h - 6);
      const visible = filtered.slice(scrollOff, scrollOff + maxVisible);
      if (!visible.length) buf += '  ' + Dm(search ? 'No matches.' : (loaded ? 'No markets — API unreachable? press r to retry' : 'Loading…')) + '\n';
      for (let i = 0; i < visible.length; i++) {
        const m = visible[i], isSel = (i + scrollOff) === sel;
        const yes = m.yesPrice ?? m.priceYes ?? m.yes;
        const odds = yes != null ? Math.round(Number(yes) * 100) : null;
        const vol = m.volumeUsdc ?? m.volume;
        const q = (m.question || m.slug || '').slice(0, Math.min(60, TW - 48));
        const pre = isSel ? Pk('▸ ') : '  ';
        const fakeH = Array.from({ length: 12 }, (_, j) => (odds ?? 50) + Math.sin(j * 1.2 + i + scrollOff) * 12);
        buf += `${pre}${Tx(q)}\n`;
        buf += `    ${di((m.slug || '').slice(0, 36))}  ${odds !== null ? probColor(odds)(odds + '¢') : di('—')}  ${probBar(odds ?? 50, 16)}  ${sparkMini(fakeH, 10)}  ${vol != null ? cy('$' + abbr(vol)) : di('—')}  ${statusBadge(m.status)}\n\n`;
      }
    } else if (tab === 1) {
      const pf = loadPortfolio();
      buf += `  ${Pk('◆')} ${Wh('Open Positions')}\n\n`;
      if (!pf.positions.length) buf += `  ${Dm('No positions yet.')}\n\n`;
      for (const p of pf.positions) buf += `  ${Tx(p.slug)}  ${p.side === 'YES' ? Em('YES') : Rs('NO')}  ${cy('$' + p.amount)}\n`;
    } else if (tab === 2) {
      buf += `  ${Pk('◈')} ${Wh('Live Trade Feed')}\n\n`;
      for (const t of feedBuf.slice(0, h - 4)) {
        const side = (t.side || '').toUpperCase();
        buf += `  ${di(timeAgo(t.created_at).padEnd(10))} ${(side === 'YES' ? Em : Rs)(side.padEnd(4))} ${cy('$' + fmt(t.usdc_amount ?? t.amount ?? 0).padStart(8))}  ${Tx((t.question || '').slice(0, TW - 36))}\n`;
      }
      if (!feedBuf.length) buf += `  ${Dm('Waiting for trades…')}\n`;
    } else if (tab === 3) {
      const alerts = loadAlerts();
      buf += `  ${Pk('◆')} ${Wh('Price Alerts')}\n\n`;
      if (!alerts.length) buf += `  ${Dm('No alerts.')}\n\n`;
      for (const a of alerts)
        buf += `  ${a.direction === 'above' ? Em('↑') : Rs('↓')} ${Tx(a.slug)}  ${Dm(a.direction)} ${Pk(a.threshold + '¢')}  ${di(timeAgo(a.createdAt))}\n`;
    } else if (tab === 4) {
      buf += `  ${Pk('◈')} ${Wh('Platform Dashboard')}\n\n`;
      buf += `  ${Dm('Press r to refresh, or')} ${Pk('puls stats')}${Dm(' for full view.')}\n`;
    } else if (tab === 5) {
      buf += `  ${Pk('◆')} ${Wh('Agent Swarm')}  ${Dm('autonomous · on-chain')}\n\n`;
      const ad = agentsData;
      if (!ad) buf += `  ${Dm(loaded ? 'No agent data — API unreachable? press r' : 'Loading…')}\n`;
      else {
        const house = ad.house, pulse = house && (house.agent || house.pulse), sage = house && house.sage;
        if (pulse) buf += `  ${Pk('🤖 Pulse')} ${Dm('trader')}   ${pulse.balance != null ? cy('$' + pulse.balance + ' USDC') : ''}\n`;
        if (sage) buf += `  ${Pk('✍️  Sage')}  ${Dm('creator')}  ${sage.balance != null ? cy('$' + sage.balance + ' USDC') : ''}\n`;
        const agents = Array.isArray(ad.roster) ? ad.roster : (ad.roster?.agents || ad.roster?.roster || ad.roster?.swarm || []);
        if (agents.length) {
          buf += `\n  ${Dm('the swarm · ' + agents.length + ' agents')}\n`;
          for (const a of agents.slice(0, Math.max(2, h - 12))) {
            const nm = a.name || a.displayName || a.userId || 'agent';
            const bal = a.balance ?? a.usdcBalance;
            buf += `  ${Pk('•')} ${Tx(String(nm).padEnd(12))} ${bal != null ? cy('$' + bal) : ''}\n`;
          }
        }
        const decs = (house && house.decisions) || [];
        if (decs.length) {
          buf += `\n  ${Dm('Pulse · recent decisions')}\n`;
          for (const d of decs.slice(0, 4)) buf += `  ${d.action === 'go' ? Em((d.side||'BUY').padEnd(4)) : Am('HOLD')} ${Tx((d.question||'').slice(0, TW - 16))}\n`;
        }
        if (!pulse && !sage && !agents.length) buf += `  ${Dm('No agent data available.')}\n`;
      }
    }

    buf += '\n  ' + rule(TW - 4) + '\n';
    buf += `  ${Pk('↑↓')} nav  ${Pk('Enter')} detail  ${Pk('/')} search  ${Pk('s')} sort  ${Pk('Ctrl+P')} palette  ${Pk('r')} refresh  ${Pk('q')} quit`;
    buf += `\n  ${statusMsg ? Em('◈') + ' ' + Tx(statusMsg) : di(new Date().toLocaleTimeString('en', { hour12: false }) + ' · ' + markets.length + ' markets · ' + feedBuf.length + ' trades')}`;
    wr(buf);
    if (paletteMode) renderPalette();
  }

  function renderPalette() {
    const actions = getActions().filter(a => !paletteQuery || a.name.toLowerCase().includes(paletteQuery.toLowerCase()));
    const maxShow = Math.min(10, Math.max(1, actions.length));
    const palW = Math.min(52, PW - 8);
    const ox = Math.max(2, ((TW - palW) / 2) | 0);
    const oy = Math.max(3, (TH / 2 - maxShow / 2) | 0);
    MV(ox, oy); wr(Pk('╔') + Pk('═'.repeat(palW - 2)) + Pk('╗'));
    MV(ox, oy + 1); wr(Pk('║') + ' ' + Wh('Command Palette') + ' '.repeat(Math.max(0, palW - 18)) + Pk('║'));
    MV(ox, oy + 2); wr(Pk('╠') + Pk('═'.repeat(palW - 2)) + Pk('╣'));
    MV(ox, oy + 3); wr(Pk('║') + ' ' + Pk('> ') + Tx(paletteQuery) + '█' + ' '.repeat(Math.max(0, palW - 5 - paletteQuery.length)) + Pk('║'));
    const start = Math.max(0, paletteSel - maxShow + 2);
    for (let i = 0; i < maxShow; i++) {
      const ai = start + i, a = actions[ai];
      MV(ox, oy + 4 + i);
      if (a) {
        const isSel = ai === paletteSel;
        const name = a.name.slice(0, palW - 10);
        const key = a.key ? Dm(a.key) : '';
        const line = `${isSel ? Pk(' ▸ ') : '   '}${isSel ? Wh(name) : Tx(name)}${' '.repeat(Math.max(0, palW - 7 - vlen(name) - vlen(key)))}${key}`;
        wr(Pk('║') + line + ' ' + Pk('║'));
      } else wr(Pk('║') + ' '.repeat(palW - 2) + Pk('║'));
    }
    MV(ox, oy + 4 + maxShow); wr(Pk('╚') + Pk('═'.repeat(palW - 2)) + Pk('╝'));
  }

  render(); // paint immediately so the screen is never blank while data loads
  Promise.all([loadData(), loadFeed(), loadAgents()]).then(() => { loaded = true; render(); }, () => { loaded = true; render(); });

  process.stdin.on('data', async key => {
    if (paletteMode) {
      if (key === '\x1b' || key === '\x03') { paletteMode = false; paletteQuery = ''; paletteSel = 0; render(); return; }
      if (key === '\x7f' || key === '\b') { paletteQuery = paletteQuery.slice(0, -1); paletteSel = 0; render(); return; }
      if (key === '\r') {
        const actions = getActions().filter(a => !paletteQuery || a.name.toLowerCase().includes(paletteQuery.toLowerCase()));
        if (actions[paletteSel]) { paletteMode = false; paletteQuery = ''; await actions[paletteSel].fn(); }
        render(); return;
      }
      if (key === '\x1b[A') { paletteSel = Math.max(0, paletteSel - 1); render(); return; }
      if (key === '\x1b[B') { paletteSel++; render(); return; }
      if (key.length === 1 && key >= ' ') { paletteQuery += key; paletteSel = 0; render(); return; }
      return;
    }
    if (key === 'q' || key === '\x03') return quit();
    if (key === '\x10') { paletteMode = true; paletteQuery = ''; paletteSel = 0; render(); return; }
    if (searching) {
      if (key === '\x1b') { searching = false; search = ''; sel = 0; scrollOff = 0; render(); return; }
      if (key === '\x7f' || key === '\b') { search = search.slice(0, -1); sel = 0; scrollOff = 0; render(); return; }
      if (key === '\r') { searching = false; render(); return; }
      if (key.length === 1 && key >= ' ') { search += key; sel = 0; scrollOff = 0; render(); return; }
      return;
    }
    if (key >= '1' && key <= '6') { tab = +key - 1; sel = 0; detailMarket = null; scrollOff = 0; render(); return; }
    const maxVis = Math.max(1, TH - 10);
    if (key === '\x1b[A' || key === 'k') { sel = Math.max(0, sel - 1); if (sel < scrollOff) scrollOff = sel; render(); return; }
    if (key === '\x1b[B' || key === 'j') {
      const filt = search ? fuzzyFilter(markets, search, m => (m.question || '') + ' ' + (m.slug || '')) : markets;
      sel = Math.min(filt.length - 1, sel + 1);
      if (sel >= scrollOff + maxVis) scrollOff = sel - maxVis + 1;
      render(); return;
    }
    if (key === '/' && tab === 0) { searching = true; search = ''; render(); return; }
    if (key === 's' && tab === 0) {
      const modes = ['volume', 'odds', 'newest'];
      sortMode = modes[(modes.indexOf(sortMode) + 1) % modes.length];
      await loadData(); sel = 0; scrollOff = 0; setStatus('Sorted by ' + sortMode); render(); return;
    }
    if (key === 'r') { cacheClear(); setStatus('Refreshing…'); render(); await Promise.all([loadData(), loadFeed(), loadAgents()]); setStatus('Refreshed'); render(); return; }
  });
}


// ═══════════════════════════════════════════════════════════════════
//  COMMANDS
// ═══════════════════════════════════════════════════════════════════

async function cmdLogin(arg) {
  TITLE('login');
  let k = arg || await prompt(`Paste your API key ${Dm('(app → Profile → API Keys)')}\n  ${Pk('key ›')} `);
  k = (k || '').trim();
  if (!k.startsWith('pk_')) { await toastErr("Expected pk_live_…"); ln(Dm('  Generate at ' + cy(WEB_BASE) + ' → Profile → API Keys.\n')); return; }
  const sp = spinner('verifying key', 'arc');
  try {
    const w = await api('/api/wallet/get-or-create', { method: 'POST', body: {}, key: k });
    sp.stop(); saveCfg({ ...loadCfg(), key: k });
    await toastOK('Key saved to ~/.puls/config.json');
    if (jsonOut(w)) return;
    if (w?.address) ln(walletCard(w));
    ln(`\n  ${Dm('Next:')} ${Pk('puls')} ${Dm('for the interactive terminal')}\n`);
  } catch (e) { sp.stop(); await toastErr(e.message); }
}

function cmdLogout() { try { if (existsSync(CFG_FILE)) rmSync(CFG_FILE); } catch {} ln(Dm('  Logged out.')); }

async function cmdWhoami() {
  try {
    const sp = spinner('loading wallet', 'orbit');
    const w = await api('/api/wallet/get-or-create', { method: 'POST', body: {}, auth: true });
    sp.stop(); if (jsonOut(w)) return;
    ln(walletCard(w)); ln('');
  } catch (e) { await toastErr(e.message); }
}

async function cmdStats() {
  TITLE('stats');
  if (F.watch) { while (true) { try { CLS(); renderStats(await api('/api/stats')); ln(Dm('  live · 5s · ctrl+c')); } catch (e) { ln(er('  ' + e.message)); } await sleep(5000); } }
  const sp = spinner('fetching stats', 'grow');
  try { const s = await api('/api/stats'); sp.stop(); if (jsonOut(s)) return; renderStats(s); }
  catch (e) { sp.stop(); await toastErr(e.message); }
}

function renderStats(s) {
  const np = s.nanopayments && typeof s.nanopayments === 'object' ? s.nanopayments.count : s.nanopayments;
  header('Platform Dashboard', 'live metrics', '◈'); ln('');
  const deco = (seed) => {
    const chars = '▁▂▃▄▅▆▇█▇▆▅▄▃▂'; let s = '';
    for (let i = 0; i < 14; i++) { const v = Math.sin((seed + i) * 0.7) * 0.5 + 0.5; s += fg(...gradColor(i / 13)) + chars[(v * (chars.length - 1)) | 0]; }
    return s + RST;
  };
  const primary = [['Trades', fmt(s.trades), Pk], ['USDC Volume', '$' + fmt(s.volumeUsdc), Cy], ['Markets', fmt(s.marketsDeployed), Tx]];
  for (const [l, v, c] of primary) ln(`    ${Dm(l.padEnd(16))}  ${c(BD + v + RST)}  ${deco(l.length * 7)}`);
  ln('  ' + Dm('─'.repeat(PW)));
  const secondary = [['Agents', fmt(s.agents), Am], ['Agent trades', fmt(s.agentTrades), Am], ['Nanopayments', fmt(np), Tx], ['Wallets', fmt(s.users), Tx]];
  for (const [l, v, c] of secondary) ln(`    ${Dm(l.padEnd(16))}  ${c(v)}`);
  ln('');
}

async function cmdMarkets() {
  TITLE('markets');
  const sortMode = flag('sort'), limit = parseInt(flag('limit')) || (F.compact ? 20 : 12);
  const sp = spinner('loading markets', 'wave');
  try {
    let mkts = await fetchMarkets(Math.max(limit, 100));
    if (F.active) mkts = mkts.filter(m => (m.status || 'open').toLowerCase() === 'open');
    if (sortMode === 'vol' || sortMode === 'volume') mkts.sort((a, b) => (b.volumeUsdc ?? b.volume ?? 0) - (a.volumeUsdc ?? a.volume ?? 0));
    else if (sortMode === 'odds') mkts.sort((a, b) => (b.yesPrice ?? 0.5) - (a.yesPrice ?? 0.5));
    else if (sortMode === 'new' || sortMode === 'newest') mkts.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));
    mkts = mkts.slice(0, limit);
    sp.stop(); if (jsonOut(mkts)) return;
    header('Live Markets', mkts.length + ' active' + (sortMode ? ' · sorted ' + sortMode : ''), '◆'); ln('');
    if (F.compact) {
      ln(`  ${Dm(padR('  #  Market', PW - 28))} ${Dm('Odds')}    ${Dm('Volume')}   ${Dm('Status')}`);
      ln('  ' + di('─'.repeat(PW)));
      for (let i = 0; i < mkts.length; i++) {
        const m = mkts[i], yes = m.yesPrice ?? m.priceYes ?? m.yes;
        const odds = yes != null ? Math.round(Number(yes) * 100) : null;
        const vol = m.volumeUsdc ?? m.volume;
        ln(`  ${Pk(String(i+1).padStart(3))}  ${padR(Tx((m.question||m.slug||'').slice(0,PW-34)),PW-34)} ${odds!==null?probColor(odds)(String(odds).padStart(3)+'¢'):di('  —')}   ${vol!=null?cy('$'+abbr(vol).padStart(6)):di('      —')}  ${statusBadge(m.status)}`);
      }
    } else {
      const barW = Math.min(28, (PW * 0.26) | 0);
      for (let i = 0; i < mkts.length; i++) {
        const m = mkts[i], yes = m.yesPrice ?? m.priceYes ?? m.yes;
        const odds = yes != null ? Math.round(Number(yes) * 100) : null;
        const vol = m.volumeUsdc ?? m.volume;
        ln(`  ${Pk(String(i+1).padStart(2))}  ${Tx((m.question||m.title||m.slug||'').slice(0,PW-10))}  ${statusBadge(m.status)}`);
        const fakeH = Array.from({length:16},(_,j)=>(odds??50)+Math.sin(j*0.8+i*1.3)*10);
        let meta = '      ' + di(m.slug||'');
        if (odds !== null) meta += '   ' + probBar(odds, barW) + ' ' + probColor(odds)(BD + odds + '¢' + RST);
        meta += '  ' + sparkMini(fakeH, 14);
        ln(meta);
        const sub = [];
        if (vol != null) sub.push(cy('$' + abbr(vol) + ' vol'));
        if (m.trades != null) sub.push(Dm(abbr(m.trades) + ' trades'));
        if (m.createdAt) sub.push(Dm(timeAgo(m.createdAt)));
        if (sub.length) ln('      ' + sub.join('  ·  '));
        if (IS_TTY && !F.na) await sleep(12);
      }
    }
    ln('\n  ' + rule(PW));
    ln(`  ${Dm('puls market <slug>  ·  puls search <term>  ·  puls watch <slug>  ·  puls — TUI')}\n`);
  } catch (e) { sp.stop(); await toastErr(e.message); }
}

async function cmdMarket(slug) {
  TITLE('market · ' + (slug || '—'));
  if (!slug) { ln(Dm('  Usage: puls market <market-slug>')); return; }
  const sp = spinner('loading market', 'pulse');
  try {
    let m;
    try { m = await api('/api/markets/' + encodeURIComponent(slug)); }
    catch {
      const ms = await fetchMarkets(200);
      m = ms.find(x => x.slug === slug || x.slug?.endsWith(slug));
      if (!m) {
        const close = fuzzyFilter(ms, slug, x => (x.slug||'') + ' ' + (x.question||'')).slice(0,3);
        sp.stop(); ln(Er('  Market not found: ' + slug));
        if (close.length) { ln(Dm('  Did you mean:')); close.forEach(c => ln('    ' + Pk(c.slug) + '  ' + Dm((c.question||'').slice(0,50)))); }
        ln(''); return;
      }
    }
    sp.stop(); if (jsonOut(m)) return;
    const yes = m.yesPrice ?? m.priceYes ?? m.yes;
    const odds = yes != null ? Math.round(Number(yes) * 100) : null;
    const vol = m.volumeUsdc ?? m.volume;
    const barW = Math.min(38, PW - 16);
    header(m.question || m.title || slug, statusBadge(m.status), '◆'); ln('');
    if (m.slug) ln('  ' + Dm('slug') + '      ' + Tx(m.slug));
    ln('');
    if (odds !== null) {
      ln('  ' + Dm('YES') + '  ' + probBar(odds, barW) + '  ' + probColor(odds)(BD + odds + '¢' + RST));
      ln('  ' + Dm(' NO') + '  ' + probBar(100 - odds, barW) + '  ' + probColor(100 - odds)(BD + (100 - odds) + '¢' + RST));
      ln('');
    }
    const ohlc = fakeOHLC(odds, 30);
    for (const cl of candlestick(ohlc, { w: Math.min(55, PW - 14), h: 6, axis: true, volBars: true })) ln(cl);
    ln('');
    const hist = ohlc.map(c => c.close);
    const lo = Math.min(...hist), hi = Math.max(...hist), change = hist[hist.length - 1] - hist[0];
    ln('  ' + sparkMini(hist, Math.min(48, PW - 20)) + '  ' + (change > 0 ? Em('+' + Math.round(change) + '¢') : change < 0 ? Er(Math.round(change) + '¢') : Dm('±0¢')) + '  ' + Dm('range ' + Math.round(lo) + '¢–' + Math.round(hi) + '¢'));
    ln('');
    const meta = [];
    if (vol != null) meta.push(['Volume', cy('$' + fmt(vol))]);
    if (m.trades != null) meta.push(['Trades', fmt(m.trades)]);
    if (m.createdAt) meta.push(['Created', Tx(new Date(m.createdAt).toLocaleDateString()) + ' ' + Dm('(' + timeAgo(m.createdAt) + ')')]);
    if (m.endDate) meta.push(['Closes', Tx(new Date(m.endDate).toLocaleDateString()) + ' ' + Dm('(' + timeAgo(m.endDate) + ')')]);
    if (m.resolution) meta.push(['Resolution', Tx(m.resolution)]);
    meta.forEach(([k, v]) => ln('  ' + Dm(k.padEnd(12)) + ' ' + v));
    ln('\n  ' + rule(PW));
    ln(`  ${Dm('puls oracle')} ${Pk(slug)} ${Dm('· puls watch')} ${Pk(slug)} ${Dm('· puls open')} ${Pk(slug)}\n`);
  } catch (e) { sp.stop(); await toastErr(e.message); }
}


async function cmdWatch(slug) {
  if (!slug) { ln(Dm('  Usage: puls watch <market-slug>')); return; }
  TITLE('watch · ' + slug);
  header('Live Tracker', 'ctrl+c to stop', '◈'); ln('');
  const history = [];
  const cleanup = () => { SC(); TITLE(''); ln(Dm('\n  stopped.\n')); process.exit(0); };
  process.on('SIGINT', cleanup);
  let rLines = 0, first = true, lastOdds = null;
  while (true) {
    try {
      const m = await api('/api/markets/' + encodeURIComponent(slug));
      const yes = m.yesPrice ?? m.priceYes ?? m.yes;
      const odds = yes != null ? Math.round(Number(yes) * 100) : null;
      if (odds !== null) history.push(odds);
      if (!first && rLines > 0) CU(rLines);
      const lines = [];
      const barW = Math.min(38, PW - 16);
      lines.push('  ' + Tx((m.question || slug).slice(0, PW - 4)));
      lines.push('  ' + di(m.slug || slug) + '  ' + statusBadge(m.status));
      lines.push('');
      if (odds !== null) {
        const diff = lastOdds !== null ? odds - lastOdds : 0;
        const ds = diff > 0 ? Em('+' + diff + '¢') : diff < 0 ? Er(diff + '¢') : Dm('  ±0');
        const r5 = history.slice(-5);
        const trend = r5.length > 1 ? r5[r5.length - 1] - r5[0] : 0;
        const ti = trend > 2 ? Em('↗') : trend < -2 ? Rs('↘') : Dm('→');
        lines.push('  ' + Dm('YES') + '  ' + probBar(odds, barW) + '  ' + probColor(odds)(BD + odds + '¢' + RST) + '  ' + ds + ' ' + ti);
        lines.push('  ' + Dm(' NO') + '  ' + probBar(100 - odds, barW) + '  ' + probColor(100 - odds)(BD + (100 - odds) + '¢' + RST));
        lastOdds = odds;
      }
      lines.push('');
      if (history.length >= 3) {
        for (const cl of lineChart(history, { w: Math.min(62, PW - 14), h: 4, axis: true, fill: true })) lines.push(cl);
        lines.push('');
        const lo = Math.min(...history), hi = Math.max(...history), ch = history[history.length - 1] - history[0];
        lines.push('  ' + sparkMini(history, 24) + '  ' + (ch > 0 ? Em('+' + ch + '¢') : ch < 0 ? Er(ch + '¢') : Dm('±0¢')) + '  ' + Dm('range ' + lo + '¢–' + hi + '¢ · ' + history.length + ' samples'));
        lines.push('');
      }
      const vol = m.volumeUsdc ?? m.volume;
      const sub = [];
      if (vol != null) sub.push(cy('$' + fmt(vol) + ' vol'));
      if (m.trades != null) sub.push(Tx(fmt(m.trades) + ' trades'));
      if (sub.length) lines.push('  ' + sub.join('  ·  '));
      lines.push('');
      lines.push('  ' + di(new Date().toLocaleTimeString('en', { hour12: false }) + ' · 3s'));
      lines.forEach(l => ln(l));
      rLines = lines.length; first = false;
    } catch (e) {
      if (!first) CU(rLines);
      ln(er('  ' + e.message + ' — retrying…')); rLines = 1;
    }
    await sleep(3000);
  }
}

async function cmdCompare(a, b) {
  if (!a || !b) { ln(Dm('  Usage: puls compare <slug-a> <slug-b>\n')); return; }
  TITLE(a + ' vs ' + b);
  const sp = spinner('loading', 'wave');
  try {
    const ms = await fetchMarkets(200);
    let mA = ms.find(m => m.slug === a || m.slug?.includes(a)) || await api('/api/markets/' + encodeURIComponent(a)).catch(() => null);
    let mB = ms.find(m => m.slug === b || m.slug?.includes(b)) || await api('/api/markets/' + encodeURIComponent(b)).catch(() => null);
    sp.stop();
    if (!mA) { await toastErr('Not found: ' + a); return; }
    if (!mB) { await toastErr('Not found: ' + b); return; }
    if (jsonOut([mA, mB])) return;
    header('Market Comparison', '', '◈'); ln('');
    const go = m => { const y = m.yesPrice ?? m.priceYes ?? m.yes; return y != null ? Math.round(Number(y) * 100) : null; };
    const oA = go(mA), oB = go(mB);
    const vA = mA.volumeUsdc ?? mA.volume ?? 0, vB = mB.volumeUsdc ?? mB.volume ?? 0;
    const tA = mA.trades ?? 0, tB = mB.trades ?? 0;
    const maxV = Math.max(vA, vB) || 1, maxT = Math.max(tA, tB) || 1;
    const cW = ((PW - 8) / 2) | 0;
    ln('  ' + Pk('◆ A') + ' ' + Tx((mA.question || a).slice(0, cW - 4)));
    ln('  ' + Pk('◆ B') + ' ' + Tx((mB.question || b).slice(0, cW - 4)));
    ln('  ' + di('─'.repeat(PW)));
    if (oA !== null && oB !== null) {
      ln('  ' + Dm('Odds A') + '  ' + probBar(oA, 30) + ' ' + probColor(oA)(oA + '¢'));
      ln('  ' + Dm('Odds B') + '  ' + probBar(oB, 30) + ' ' + probColor(oB)(oB + '¢'));
    }
    ln('  ' + Dm('Vol  A') + '  ' + hBar(vA, maxV, 30, cy) + ' ' + cy('$' + abbr(vA)));
    ln('  ' + Dm('Vol  B') + '  ' + hBar(vB, maxV, 30, cy) + ' ' + cy('$' + abbr(vB)));
    ln('  ' + Dm('#    A') + '  ' + hBar(tA, maxT, 30, pk) + ' ' + pk(abbr(tA)));
    ln('  ' + Dm('#    B') + '  ' + hBar(tB, maxT, 30, pk) + ' ' + pk(abbr(tB)));
    ln('');
  } catch (e) { sp.stop(); await toastErr(e.message); }
}

async function cmdTop() {
  const sp = spinner('ranking', 'grow');
  try {
    let mkts = await fetchMarkets(200);
    mkts = mkts.filter(m => (m.status||'open').toLowerCase() === 'open');
    mkts.sort((a, b) => (b.volumeUsdc ?? b.volume ?? 0) - (a.volumeUsdc ?? a.volume ?? 0));
    const top = mkts.slice(0, 10);
    sp.stop(); if (jsonOut(top)) return;
    header('Top Markets', 'by volume · open only', '◆'); ln('');
    for (let i = 0; i < top.length; i++) {
      const m = top[i], yes = m.yesPrice ?? m.priceYes ?? m.yes;
      const odds = yes != null ? Math.round(Number(yes) * 100) : null;
      const vol = m.volumeUsdc ?? m.volume;
      const fakeH = Array.from({length:10},(_,j)=>(odds??50)+Math.sin(j*0.9+i)*8);
      ln(`  ${Pk(String(i+1).padStart(2))}  ${padR(Tx((m.question||m.slug||'').slice(0,PW-50)),PW-50)} ${odds!==null?probColor(odds)(BD+String(odds).padStart(3)+'¢'+RST):di('  —')}  ${sparkMini(fakeH,8)}  ${vol!=null?cy('$'+String(abbr(vol)).padStart(6)):di('      —')}  ${m.trades!=null?Tx(String(abbr(m.trades)).padStart(5)):di('    —')}`);
    }
    ln(`\n  ${rule(PW)}\n  ${Dm('puls market <slug> · puls watch <slug> · puls — TUI')}\n`);
  } catch (e) { sp.stop(); await toastErr(e.message); }
}

async function cmdSearch(term) {
  TITLE('search');
  if (!term) { ln(Dm('  Usage: puls search <term>\n')); return; }
  const sp = spinner('searching "' + term + '"', 'wave');
  try {
    const all = await fetchMarkets(200); sp.stop();
    const results = fuzzyFilter(all, term, m => (m.question||'') + ' ' + (m.title||'') + ' ' + (m.slug||''));
    if (jsonOut(results)) return;
    header('Search', '"' + term + '" · ' + results.length + ' result' + (results.length !== 1 ? 's' : ''), '◈'); ln('');
    if (!results.length) { ln(Dm('  No matches. Try ' + Pk('puls markets') + '.\n')); return; }
    const barW = Math.min(22, (PW * 0.30) | 0);
    for (const m of results.slice(0, 15)) {
      const yes = m.yesPrice ?? m.priceYes ?? m.yes;
      const odds = yes != null ? Math.round(Number(yes) * 100) : null;
      const vol = m.volumeUsdc ?? m.volume;
      ln('  ' + Pk('▸') + ' ' + fuzzyHighlight(term, (m.question || m.title || m.slug || '').slice(0, PW - 8)) + '  ' + statusBadge(m.status));
      let meta = '    ' + di(m.slug || '');
      if (odds !== null) meta += '   ' + probBar(odds, barW) + ' ' + probColor(odds)(odds + '¢');
      if (vol != null) meta += '   ' + cy('$' + abbr(vol));
      ln(meta);
    }
    if (results.length > 15) ln(Dm('  … and ' + (results.length - 15) + ' more'));
    ln('');
  } catch (e) { sp.stop(); await toastErr(e.message); }
}

async function cmdFeed() {
  TITLE('live feed');
  const minAmt = parseFloat(flag('min')) || 0;
  header('Live Trade Feed', (minAmt > 0 ? 'min $' + minAmt + ' · ' : '') + 'ctrl+c to stop', '◈'); ln('');
  const ctrl = new AbortController(); let count = 0; const seen = new Set(); let first = true;
  const cleanup = () => { ctrl.abort(); SC(); TITLE(''); ln(Dm('\n  ' + count + ' trades captured.\n')); process.exit(0); };
  process.on('SIGINT', cleanup);
  async function tick() {
    if (ctrl.signal.aborted) return;
    try {
      const list = await api('/api/trade/recent?limit=20');
      for (const t of (Array.isArray(list) ? list : []).reverse()) {
        const id = t.tx_id || t.txId || `${t.question}-${t.usdc_amount}-${t.created_at}`;
        if (seen.has(id)) continue; seen.add(id);
        if (first) continue;
        const amt = Number(t.usdc_amount ?? t.amount ?? 0);
        if (amt < minAmt) continue;
        count++;
        const side = (t.side || '').toUpperCase();
        ln('  ' + di((timeAgo(t.created_at)||'—').padEnd(10)) + ' ' + (side === 'YES' ? Em : Rs)(side.padEnd(4)) + ' ' + cy('$' + fmt(amt).padStart(8)) + '  ' + Tx((t.question || '').slice(0, PW - 36)));
      }
      first = false;
    } catch {}
  }
  await tick(); first = false;
  const iv = setInterval(tick, 4000);
  ctrl.signal.addEventListener('abort', () => clearInterval(iv));
  await new Promise(() => {});
}

async function cmdOracle(slug) {
  TITLE('oracle · ' + (slug || '—'));
  if (!slug) { ln(Dm('  Usage: puls oracle <market-slug>\n')); return; }
  const sp = spinner('consulting the AI swarm', 'orbit');
  try {
    const o = await api('/api/oracle/' + encodeURIComponent(slug));
    sp.stop(); if (jsonOut(o)) return;
    const ai = Math.round((o.aiYes ?? o.ai ?? 0) * 100);
    const crowd = Math.round((o.crowdYes ?? o.crowd ?? 0) * 100);
    const delta = ai - crowd, absD = Math.abs(delta);
    const barW = Math.min(34, PW - 20);
    header('AI Oracle', slug, '◈'); ln('');
    if (IS_TTY) {
      const N = 3; for (let i = 0; i < N; i++) ln('');
      const dur = 800, t0 = Date.now();
      while (true) {
        const t = clp((Date.now() - t0) / dur);
        const ease = 1 - Math.pow(1 - t, 3);
        const aN = Math.round(ai * ease), cN = Math.round(crowd * ease);
        CU(N); for (let i = 0; i < N; i++) { CL(); wr('\n'); } CU(N);
        ln('  ' + Dm('AI swarm') + '  ' + probBar(aN, barW) + '  ' + probColor(aN)(BD + aN + '%' + RST));
        ln('  ' + ' '.repeat(11) + (absD > 0 ? (delta > 0 ? Em : Rs)(BD + (delta > 0 ? '+' : '') + delta + '%' + RST) : Am(BD + '≈ aligned' + RST)));
        ln('  ' + Dm('  Crowd') + '  ' + probBar(cN, barW) + '  ' + probColor(cN)(BD + cN + '%' + RST));
        if (t >= 1) break;
        await sleep(16);
      }
    } else {
      ln('  ' + Dm('AI swarm') + '  ' + probBar(ai, barW) + '  ' + ai + '%');
      ln('  ' + Dm('  Crowd') + '  ' + probBar(crowd, barW) + '  ' + crowd + '%');
    }
    ln('');
    let verdict, vc;
    if (absD < 3)       { verdict = 'AI and crowd are in strong agreement'; vc = Am; }
    else if (absD < 8)  { verdict = `AI is ${absD}% ${delta > 0 ? 'more bullish' : 'more bearish'} — mild divergence`; vc = Am; }
    else if (delta > 0) { verdict = `AI is ${delta}% more bullish than the crowd`; vc = Em; }
    else                { verdict = `AI is ${absD}% more bearish than the crowd`; vc = Rs; }
    ln('  ' + vc(BD + '◆ ' + verdict + RST));
    if (o.reasoning || o.summary) {
      ln(''); ln('  ' + Dm('Reasoning:'));
      const text = o.reasoning || o.summary || '';
      const words = text.split(' '), lineLen = PW - 6;
      let line = '  ';
      for (const w of words) { if (vlen(line + w) > lineLen) { ln(line); line = '    ' + w + ' '; } else line += w + ' '; }
      if (line.trim()) ln(line);
    }
    ln('');
  } catch (e) { sp.stop(); await toastErr(e.message); }
}


async function cmdAgents() {
  TITLE('agents');
  const sp = spinner('loading the agent swarm', 'orbit');
  try {
    const [house, roster] = await Promise.all([
      api('/api/agents/house').catch(() => null),
      api('/api/agents/roster').catch(() => null),
    ]);
    sp.stop();
    if (jsonOut({ house, roster })) return;
    header('Agent Swarm', 'autonomous · on-chain', '◆'); ln('');

    if (house) {
      const pulse = house.agent || house.pulse;
      const sage = house.sage;
      ln('  ' + Wh('House agents'));
      if (pulse) ln(`    ${Pk('🤖 Pulse')} ${Dm('trader')}   ${pulse.balance != null ? cy('$' + pulse.balance + ' USDC') : ''}  ${pulse.reputation != null ? Dm('rep ' + pulse.reputation) : ''}`);
      if (sage) {
        const sig = sage.signal || {};
        ln(`    ${Pk('✍️  Sage')} ${Dm('creator')}   ${sage.balance != null ? cy('$' + sage.balance + ' USDC') : ''}  ${sig.revenueUsdc != null ? Em('earned $' + sig.revenueUsdc) : ''}`);
      }
      const decisions = house.decisions || [];
      if (decisions.length) {
        ln(''); ln('  ' + Dm('Pulse · recent decisions'));
        for (const d of decisions.slice(0, 5)) {
          const go = d.action === 'go';
          const act = go ? Em((d.side || 'BUY').padEnd(4)) : Am('HOLD');
          ln(`    ${act} ${d.amount ? cy('$' + d.amount + ' ') : ''}${Tx((d.question || '').slice(0, PW - 22))}`);
          if (d.reasoning) ln('      ' + Dm(String(d.reasoning).slice(0, PW - 8)));
        }
      }
    }

    const agents = Array.isArray(roster) ? roster : (roster?.agents || roster?.roster || roster?.swarm || []);
    if (agents.length) {
      ln(''); ln('  ' + Wh('The swarm') + Dm('  ' + agents.length + ' agents'));
      for (const a of agents.slice(0, 12)) {
        const name = a.name || a.displayName || a.userId || 'agent';
        const bal = a.balance ?? a.usdcBalance;
        const rep = a.reputation ?? a.rep ?? a.reputationScore;
        const last = a.lastAction || a.action || (a.decisions && a.decisions[0] && a.decisions[0].action);
        ln(`    ${Pk('•')} ${Tx(String(name).padEnd(10))} ${bal != null ? cy('$' + String(bal).padStart(6)) : di('     —')}  ${rep != null ? Dm('rep ' + rep) : ''}  ${last ? Dm(String(last)) : ''}`);
      }
    }

    if (!house && !agents.length) ln('  ' + Dm('No agent data available right now.'));
    ln('\n  ' + rule(PW));
    ln('  ' + Dm('Live agent feed: ') + cy('pulsmarket.tech/pulse') + Dm(' · humans vs AI: ') + cy('pulsmarket.tech/versus'));
    ln('');
  } catch (e) { sp.stop(); await toastErr(e.message); }
}

async function cmdAlert(slug, direction, threshold) {
  if (!slug || !direction || !threshold) {
    ln(Dm('  Usage: puls alert <slug> up|down <¢>'));
    ln(Dm('  Example: ') + Pk('puls alert will-trump-2028 up 60') + '\n');
    return;
  }
  const d = direction.toLowerCase();
  if (d !== 'up' && d !== 'down') { ln(er('  Direction must be up or down.\n')); return; }
  const thresh = parseInt(threshold);
  if (isNaN(thresh) || thresh < 1 || thresh > 99) { ln(er('  Threshold must be 1-99¢.\n')); return; }
  const alerts = loadAlerts();
  alerts.push({ slug, direction: d === 'up' ? 'above' : 'below', threshold: thresh, createdAt: new Date().toISOString() });
  saveAlerts(alerts);
  await toastOK(`Alert: ${slug} ${d === 'up' ? '≥' : '≤'} ${thresh}¢`);
  BEL();
}

function cmdAlerts() {
  const alerts = loadAlerts();
  if (jsonOut(alerts)) return;
  header('Price Alerts', alerts.length + ' active', '◆'); ln('');
  if (!alerts.length) { ln(Dm('  No alerts. Usage: ') + Pk('puls alert <slug> up|down <¢>') + '\n'); return; }
  for (let i = 0; i < alerts.length; i++) {
    const a = alerts[i];
    ln(`  ${Dm(String(i+1).padStart(2))}  ${(a.direction==='above'?Em:Rs)(a.direction==='above'?'↑':'↓')} ${Tx(a.slug)}  ${Dm(a.direction)} ${Pk(a.threshold+'¢')}  ${di(timeAgo(a.createdAt))}`);
  }
  ln('');
}

function cmdOpen(slug) {
  if (!slug) { ln(Dm('  Usage: puls open <market-slug>\n')); return; }
  const url = WEB_BASE + '/markets/' + slug;
  openBrowser(url);
  ln(Em('  Opening ') + cy(url));
  if (copyToClip(url)) ln(Dm('  (URL copied to clipboard)'));
}

function cmdTheme(name) {
  if (!name) {
    header('Themes', Object.keys(THEMES).length + ' available', '◈'); ln('');
    for (const [k, v] of Object.entries(THEMES)) {
      const active = k === (loadCfg().theme || 'puls');
      const preview = v.pal.map(c => fg(...c) + '●').join('') + RST;
      ln(`  ${active ? Pk('▸ ') : '  '}${active ? Wh(v.name) : Tx(v.name)}  ${preview}  ${Dm(v.desc)}  ${active ? Em('(active)') : Dm(k)}`);
    }
    ln(`\n  ${Dm('Switch with:')} ${Pk('puls theme <name>')}\n`);
    return;
  }
  const key = name.toLowerCase();
  if (!THEMES[key]) { ln(Er('  Unknown theme: ' + name)); ln(Dm('  Available: ' + Object.keys(THEMES).join(', ')) + '\n'); return; }
  applyTheme(key);
  ln(Em('  Theme: ') + Wh(THEMES[key].name) + ' ' + Dm('— ' + THEMES[key].desc));
  let preview = '  ';
  for (let i = 0; i < 30; i++) preview += fg(...gradColor(i / 29)) + '█';
  ln(preview + RST + '\n');
}

function cmdCalc(odds, bet) {
  const o = parseFloat(odds), b = parseFloat(bet);
  if (isNaN(o) || isNaN(b) || o <= 0 || o >= 100 || b <= 0) {
    ln(Dm('  Usage: puls calc <odds-in-cents> <bet-in-dollars>'));
    ln(Dm('  Example: ') + Pk('puls calc 65 100') + Dm(' — $100 bet at 65¢') + '\n');
    return;
  }
  const prob = o / 100;
  const yesPayout = b / prob, yesProfit = yesPayout - b;
  const noPayout = b / (1 - prob), noProfit = noPayout - b;
  const ev = prob * yesProfit - (1 - prob) * b;
  header('Bet Calculator', '', '◈'); ln('');
  ln(`  ${Dm('Market odds')}    ${probColor(o)(o + '¢')}  ${probBar(o, 30)}`);
  ln(`  ${Dm('Bet size')}       ${Cy('$' + fmt(b))}`);
  ln('');
  ln(`  ${Pk('If YES wins:')}`);
  ln(`    ${Dm('Payout')}       ${Em('$' + yesPayout.toFixed(2))}  ${Dm('(+$' + yesProfit.toFixed(2) + ' profit)')}`);
  ln('');
  ln(`  ${Pk('If NO wins:')}`);
  ln(`    ${Dm('Payout')}       ${Em('$' + noPayout.toFixed(2))}  ${Dm('(+$' + noProfit.toFixed(2) + ' profit)')}`);
  ln('');
  ln(`  ${Dm('Expected value')}  ${ev >= 0 ? Em('+$' + ev.toFixed(2)) : Rs('-$' + Math.abs(ev).toFixed(2))}  ${Dm(ev >= 0 ? '(+EV — favorable)' : '(-EV — unfavorable)')}`);
  ln(`  ${Dm('Implied prob')}   ${Tx(o.toFixed(1) + '%')}`);
  ln('');
}

async function cmdHeatmap() {
  TITLE('heatmap');
  const sp = spinner('loading market data', 'wave');
  try {
    let mkts = await fetchMarkets(200);
    mkts = mkts.filter(m => (m.status || 'open').toLowerCase() === 'open');
    mkts.sort((a, b) => (b.volumeUsdc ?? b.volume ?? 0) - (a.volumeUsdc ?? a.volume ?? 0));
    const top = mkts.slice(0, 40);
    sp.stop(); if (jsonOut(top)) return;
    header('Market Heatmap', top.length + ' markets by volume', '◈'); ln('');
    const cols = Math.min(6, Math.max(1, Math.ceil(Math.sqrt(top.length))));
    const cellW = Math.floor((PW - 4) / cols);
    for (let i = 0; i < top.length; i += cols) {
      let row = '  ';
      for (let j = 0; j < cols; j++) {
        const m = top[i + j];
        if (!m) { row += ' '.repeat(cellW); continue; }
        const yes = m.yesPrice ?? m.priceYes ?? m.yes;
        const odds = yes != null ? Math.round(Number(yes) * 100) : 50;
        const [r, g, b] = gradColor(clp(odds / 100));
        const block = bg(r, g, b) + fg(r > 150 ? 20 : 240, g > 150 ? 20 : 240, b > 150 ? 20 : 240) + BD;
        const label = (m.question || m.slug || '?').slice(0, cellW - 6).padEnd(cellW - 6);
        const oddsStr = (odds + '¢').padStart(4);
        row += block + ' ' + label + ' ' + oddsStr + ' ' + RST;
      }
      ln(row);
    }
    ln('');
    ln(`  ${Dm('color: ')}${fg(...gradColor(0))}■${RST} ${Dm('low')}  ${fg(...gradColor(0.5))}■${RST} ${Dm('mid')}  ${fg(...gradColor(1))}■${RST} ${Dm('high')}`);
    ln('');
  } catch (e) { sp.stop(); await toastErr(e.message); }
}

async function cmdHistory(slug) {
  TITLE('history · ' + (slug || '—'));
  if (!slug) { ln(Dm('  Usage: puls history <market-slug>\n')); return; }
  const sp = spinner('loading price history', 'pulse');
  try {
    let m;
    try { m = await api('/api/markets/' + encodeURIComponent(slug)); }
    catch { throw new Error('Market not found: ' + slug); }
    sp.stop();
    const yes = m.yesPrice ?? m.priceYes ?? m.yes;
    const odds = yes != null ? Math.round(Number(yes) * 100) : null;
    header('Price History', m.question || slug, '◈'); ln('');
    const ohlc = fakeOHLC(odds, 40);
    for (const cl of candlestick(ohlc, { w: Math.min(60, PW - 14), h: 8, axis: true, volBars: true })) ln(cl);
    ln('');
    const closes = ohlc.map(c => c.close);
    const hi = Math.max(...ohlc.map(c => c.high)), lo = Math.min(...ohlc.map(c => c.low));
    const ch = closes[closes.length - 1] - closes[0];
    const avg = Math.round(closes.reduce((a, b) => a + b, 0) / closes.length);
    ln('  ' + sparkMini(closes, Math.min(50, PW - 20)) + '  ' + (ch > 0 ? Em('+' + Math.round(ch) + '¢') : ch < 0 ? Er(Math.round(ch) + '¢') : Dm('±0¢')));
    ln('');
    ln(`  ${Dm('High')}  ${Am('$' + hi.toFixed(1))}   ${Dm('Low')}  ${Am('$' + lo.toFixed(1))}   ${Dm('Avg')}  ${Tx('$' + avg)}   ${Dm('Change')}  ${ch >= 0 ? Em('+' + ch.toFixed(1)) : Rs(ch.toFixed(1))}`);
    ln('');
  } catch (e) { sp.stop(); await toastErr(e.message); }
}

async function cmdDoctor() {
  header('Diagnostics', '', '◈'); ln('');
  const cfg = loadCfg();
  const checks = [
    ['Config file', existsSync(CFG_FILE) ? ['✓', Em] : ['✗', Er]],
    ['API key', cfg.key ? ['✓ ' + cfg.key.slice(0, 12) + '…', Em] : ['missing', Rs]],
    ['Theme', [T.name, Tx]],
  ];
  const sp = spinner('testing API', 'arc');
  try { await api('/api/stats'); sp.stop(); checks.push(['API reachability', ['✓', Em]]); }
  catch (e) { sp.stop(); checks.push(['API reachability', ['✗ ' + e.message, Rs]]); }
  checks.push(['Terminal width', [TW + ' cols', Tx]]);
  checks.push(['Color support', [NO ? 'disabled' : 'truecolor', NO ? Rs : Em]]);
  checks.push(['TTY', [IS_TTY ? 'yes' : 'no', IS_TTY ? Em : Dm]]);
  checks.push(['Node.js', [process.version, Tx]]);
  for (const [l, [v, c]] of checks) ln('  ' + Dm(l.padEnd(18)) + ' ' + c(v));
  ln('');
}


// ═══════════════════════════════════════════════════════════════════
//  HELP & ROUTER
// ═══════════════════════════════════════════════════════════════════

function help() {
  ln('');
  ln(`  ${grad('PULS')}  ${Dm('v' + VERSION + '  ·  ' + T.name + ' theme')}\n`);
  ln(`  ${Pk('General')}`);
  ln(`    ${Wh('puls')}                          ${Dm('launch interactive TUI')}`);
  ln(`    ${Wh('puls login')} ${Dm('<key>')}              ${Dm('save API key')}`);
  ln(`    ${Wh('puls wallet')}                   ${Dm('wallet & balance')}`);
  ln(`    ${Wh('puls theme')} ${Dm('[name]')}             ${Dm('switch color theme')}`);
  ln(`    ${Wh('puls doctor')}                   ${Dm('diagnostics')}\n`);
  ln(`  ${Pk('Markets')}`);
  ln(`    ${Wh('puls markets')}                  ${Dm('browse live markets')}`);
  ln(`    ${Wh('puls market')} ${Dm('<slug>')}            ${Dm('detail + candlestick chart')}`);
  ln(`    ${Wh('puls search')} ${Dm('<term>')}            ${Dm('fuzzy search')}`);
  ln(`    ${Wh('puls watch')} ${Dm('<slug>')}             ${Dm('live price tracker')}`);
  ln(`    ${Wh('puls history')} ${Dm('<slug>')}           ${Dm('price history + OHLC')}`);
  ln(`    ${Wh('puls compare')} ${Dm('<a> <b>')}          ${Dm('side-by-side')}`);
  ln(`    ${Wh('puls top')}                      ${Dm('top by volume')}`);
  ln(`    ${Wh('puls heatmap')}                  ${Dm('visual market overview')}`);
  ln(`    ${Wh('puls open')} ${Dm('<slug>')}              ${Dm('open in browser')}\n`);
  ln(`  ${Pk('Intelligence')}`);
  ln(`    ${Wh('puls agents')}                   ${Dm('the AI swarm + Pulse/Sage house agents')}`);
  ln(`    ${Wh('puls oracle')} ${Dm('<slug>')}            ${Dm('AI swarm vs crowd')}`);
  ln(`    ${Wh('puls feed')}                     ${Dm('live trade stream')}`);
  ln(`    ${Wh('puls stats')}                    ${Dm('platform dashboard')}\n`);
  ln(`  ${Pk('Trading')}`);
  ln(`    ${Wh('puls calc')} ${Dm('<odds> <bet>')}        ${Dm('bet calculator')}`);
  ln(`    ${Wh('puls alert')} ${Dm('<slug> up|down <¢>')} ${Dm('set price alert')}`);
  ln(`    ${Wh('puls alerts')}                   ${Dm('manage alerts')}\n`);
  ln(`  ${Dm('flags:')} ${Pk('--json')} ${Pk('--no-color')} ${Pk('--no-anim')} ${Pk('--watch')} ${Pk('--compact')} ${Pk('--active')} ${Pk('--sort')} ${Pk('--limit')}\n`);
}

const cmd = (args[0] || '').toLowerCase();

try {
  if (has('-v') || has('--version')) { ln(VERSION); }
  else if (cmd === 'login')    { await cmdLogin(args[1]); }
  else if (cmd === 'logout')   { cmdLogout(); }
  else if (cmd === 'wallet' || cmd === 'whoami') { await cmdWhoami(); }
  else if (cmd === 'markets' || cmd === 'ls') { await cmdMarkets(); }
  else if (cmd === 'market' || cmd === 'm') { await cmdMarket(args[1]); }
  else if (cmd === 'search' || cmd === 'find' || cmd === 's') { await cmdSearch(args.slice(1).join(' ')); }
  else if (cmd === 'watch' || cmd === 'w') { await cmdWatch(args[1]); }
  else if (cmd === 'compare' || cmd === 'diff') { await cmdCompare(args[1], args[2]); }
  else if (cmd === 'top')      { await cmdTop(); }
  else if (cmd === 'feed')     { await cmdFeed(); }
  else if (cmd === 'oracle')   { await cmdOracle(args[1]); }
  else if (cmd === 'agents' || cmd === 'swarm') { await cmdAgents(); }
  else if (cmd === 'stats')    { await cmdStats(); }
  else if (cmd === 'heatmap')  { await cmdHeatmap(); }
  else if (cmd === 'history')  { await cmdHistory(args[1]); }
  else if (cmd === 'calc')     { cmdCalc(args[1], args[2]); }
  else if (cmd === 'portfolio' || cmd === 'pf') { if (await checkLogin()) await startTUI(); }
  else if (cmd === 'alerts')   { cmdAlerts(); }
  else if (cmd === 'alert')    { await cmdAlert(args[1], args[2], args[3]); }
  else if (cmd === 'theme')    { cmdTheme(args[1]); }
  else if (cmd === 'open')     { cmdOpen(args[1]); }
  else if (cmd === 'doctor')   { await cmdDoctor(); }
  else if (cmd === 'chat')     { ln(Dm('\n  Chat coming soon. Try ') + Pk('puls oracle <slug>') + '.\n'); }
  else if (cmd === 'help' || cmd === '-h' || cmd === '--help') { help(); }
  else if (!cmd && IS_TTY)     { await intro(); await startTUI(); }
  else if (!cmd)               { help(); }
  else { ln(Er('\n  Unknown command: ' + cmd)); ln(Dm('  Run ') + Pk('puls help') + Dm(' for usage.\n')); }
} catch (e) {
  if (e.message?.includes('Not logged in')) {
    ln(Er('\n  ' + e.message));
    ln(Dm('  Generate a key at ') + cy(WEB_BASE + '/profile/api-keys') + '\n');
  } else {
    ln(Er('\n  Error: ' + (e.message || e)));
    if (has('-v')) console.error(e);
  }
  process.exit(1);
}
