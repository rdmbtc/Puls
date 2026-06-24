#!/usr/bin/env node
/**
 * Puls CLI — talk to your AI agent and the live Puls market from your terminal.
 *
 *   puls login pk_live_…     save your API key (Profile → API Keys in the app)
 *   puls chat                chat with your agent (buys, holds, cites sources)
 *   puls markets             live prediction markets
 *   puls feed                live trade stream
 *   puls oracle <slug>       AI swarm vs the crowd on a market
 *   puls stats               platform traction
 *   puls whoami              your wallet + balance
 *
 * Zero dependencies. Node >= 18 (uses global fetch). Truecolor terminal.
 */
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import readline from 'node:readline';

const API = (process.env.PULS_API || 'https://api.pulsmarket.tech').replace(/\/+$/, '');
const APP_URL = 'https://app.pulsmarket.tech';
const CFG_DIR = join(homedir(), '.puls');
const CFG_FILE = join(CFG_DIR, 'config.json');
const TTY = process.stdout.isTTY && !process.env.PULS_NO_ANIM;

// ── ANSI / truecolor ────────────────────────────────────────────────────────
const E = '\x1b[';
const RESET = `${E}0m`;
const BOLD = `${E}1m`;
const DIM = `${E}2m`;
const ITAL = `${E}3m`;
const fg = (r, g, b) => `${E}38;2;${r};${g};${b}m`;
const up = (n) => process.stdout.write(`${E}${n}A`);
const clearLine = () => process.stdout.write(`${E}2K\r`);
const hideCursor = () => TTY && process.stdout.write(`${E}?25l`);
const showCursor = () => TTY && process.stdout.write(`${E}?25h`);

// Brand gradient stops: pink #EC4899 → pink-light #F472B6 → mint #2DD4BF.
const STOPS = [
  [236, 72, 153],
  [244, 114, 182],
  [45, 212, 191],
];
const lerp = (a, b, t) => Math.round(a + (b - a) * t);
function gradAt(t) {
  t = Math.max(0, Math.min(1, t));
  const seg = t * (STOPS.length - 1);
  const i = Math.min(STOPS.length - 2, Math.floor(seg));
  const f = seg - i;
  const [r1, g1, b1] = STOPS[i];
  const [r2, g2, b2] = STOPS[i + 1];
  return [lerp(r1, r2, f), lerp(g1, g2, f), lerp(b1, b2, f)];
}
/** Gradient a single-line string; `hi` (0..1) adds a moving white shimmer band. */
function grad(text, hi = null) {
  const chars = [...text];
  let out = '';
  for (let i = 0; i < chars.length; i++) {
    const t = chars.length <= 1 ? 0 : i / (chars.length - 1);
    let [r, g, b] = gradAt(t);
    if (hi !== null) {
      const d = Math.abs(t - hi);
      if (d < 0.12) {
        const k = (1 - d / 0.12) * 0.85; // blend toward white near the band
        r = lerp(r, 255, k);
        g = lerp(g, 255, k);
        b = lerp(b, 255, k);
      }
    }
    out += fg(r, g, b) + chars[i];
  }
  return out + RESET;
}
const pink = (s) => `${fg(236, 72, 153)}${s}${RESET}`;
const mint = (s) => `${fg(45, 212, 191)}${s}${RESET}`;
const amber = (s) => `${fg(245, 158, 11)}${s}${RESET}`;
const muted = (s) => `${DIM}${s}${RESET}`;
const ok = (s) => `${fg(34, 197, 94)}${s}${RESET}`;
const red = (s) => `${fg(239, 68, 68)}${s}${RESET}`;

// ── Banner ("PULS" — ANSI Shadow) + pulse-wave shimmer ───────────────────────
const BANNER = [
  '██████╗ ██╗   ██╗██╗     ███████╗',
  '██╔══██╗██║   ██║██║     ██╔════╝',
  '██████╔╝██║   ██║██║     ███████╗',
  '██╔═══╝ ██║   ██║██║     ╚════██║',
  '██║     ╚██████╔╝███████╗███████║',
  '╚═╝      ╚═════╝ ╚══════╝╚══════╝',
];
const WAVE_CH = '▁▂▃▄▅▆▇█▇▆▅▄▃▂▁';
function waveLine(width, phase) {
  let s = '';
  for (let i = 0; i < width; i++) {
    // a travelling pulse blip over a flat baseline
    const d = (i - phase + width) % width;
    s += d < WAVE_CH.length ? WAVE_CH[d] : '─';
  }
  return s;
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function intro() {
  const w = BANNER[0].length;
  if (!TTY) {
    console.log(grad(BANNER.join('\n')));
    console.log(grad('the market for what happens next'));
    return;
  }
  hideCursor();
  // 1) shimmer sweep across the banner
  for (let f = -6; f <= 22; f++) {
    const hi = f / 22;
    let buf = BANNER.map((line) => grad(line, hi)).join('\n');
    process.stdout.write(buf + '\n');
    if (f < 22) {
      up(BANNER.length);
      await sleep(28);
    }
  }
  // 2) a brief pulse-wave under it
  process.stdout.write('\n');
  for (let p = 0; p < w; p += 2) {
    clearLine();
    process.stdout.write(grad(waveLine(w, p)));
    await sleep(22);
  }
  clearLine();
  process.stdout.write(grad(waveLine(w, Math.floor(w / 2))) + '\n');
  console.log(muted('  the market for what happens next') + '\n');
  showCursor();
}

// ── Spinner ──────────────────────────────────────────────────────────────────
const SP = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
function spinner(label) {
  if (!TTY) {
    process.stdout.write(`  ${label}\n`);
    return { stop() {} };
  }
  let i = 0;
  hideCursor();
  const timer = setInterval(() => {
    clearLine();
    process.stdout.write(`  ${mint(SP[i % SP.length])} ${muted(label)}`);
    i++;
  }, 80);
  return {
    stop() {
      clearInterval(timer);
      clearLine();
      showCursor();
    },
  };
}

// ── Config ─────────────────────────────────────────────────────────────────
function loadCfg() {
  try {
    return JSON.parse(readFileSync(CFG_FILE, 'utf8'));
  } catch {
    return {};
  }
}
function saveCfg(cfg) {
  if (!existsSync(CFG_DIR)) mkdirSync(CFG_DIR, { recursive: true });
  writeFileSync(CFG_FILE, JSON.stringify(cfg, null, 2), { mode: 0o600 });
}

// ── API ──────────────────────────────────────────────────────────────────────
async function api(path, { method = 'GET', body, auth = false } = {}) {
  const headers = { accept: 'application/json' };
  if (body) headers['content-type'] = 'application/json';
  if (auth) {
    const key = loadCfg().key;
    if (!key) throw new Error('Not logged in. Run:  puls login pk_live_…');
    headers.authorization = `Bearer ${key}`;
  }
  let res;
  try {
    res = await fetch(`${API}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (e) {
    throw new Error(`Network error: ${e.message}`);
  }
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  if (!res.ok) throw new Error((data && data.error) || `HTTP ${res.status}`);
  return data;
}

function fmt(n) {
  const v = Number(n) || 0;
  return v.toLocaleString('en-US');
}

// ── Commands ───────────────────────────────────────────────────────────────
async function cmdLogin(arg) {
  let key = arg;
  if (!key) {
    key = await prompt(`Paste your API key ${muted('(app → Profile → API Keys)')}\n  ${pink('key ›')} `);
  }
  key = (key || '').trim();
  if (!key.startsWith('pk_')) {
    console.log(red('  That doesn’t look like a Puls key (expected pk_live_…).'));
    console.log(muted(`  Generate one at ${APP_URL} → Profile → API Keys.`));
    return;
  }
  const sp = spinner('verifying key…');
  try {
    const w = await apiWithKey('/api/wallet/get-or-create', {}, key);
    sp.stop();
    saveCfg({ ...loadCfg(), key });
    console.log(ok('  ✓ Logged in.') + muted('  key saved to ~/.puls/config.json'));
    if (w && w.address) console.log(`  ${muted('wallet')} ${w.address}   ${muted('balance')} ${mint('$' + (w.usdcBalance ?? '0'))}`);
    console.log(`\n  Try:  ${pink('puls chat')}\n`);
  } catch (e) {
    sp.stop();
    console.log(red(`  ✗ ${e.message}`));
    console.log(muted('  Make sure the key is active (Profile → API Keys).'));
  }
}

async function apiWithKey(path, body, key) {
  const res = await fetch(`${API}${path}`, {
    method: 'POST',
    headers: { accept: 'application/json', 'content-type': 'application/json', authorization: `Bearer ${key}` },
    body: JSON.stringify(body || {}),
  });
  const text = await res.text();
  let data;
  try { data = JSON.parse(text); } catch { data = text; }
  if (!res.ok) throw new Error((data && data.error) || `HTTP ${res.status}`);
  return data;
}

function cmdLogout() {
  try {
    if (existsSync(CFG_FILE)) rmSync(CFG_FILE);
  } catch {}
  console.log(muted('  Logged out — key removed.'));
}

async function cmdWhoami() {
  const sp = spinner('reading your wallet…');
  try {
    const w = await api('/api/wallet/get-or-create', { method: 'POST', body: {}, auth: true });
    sp.stop();
    console.log(`\n  ${grad('Your Puls wallet')}`);
    console.log(`  ${muted('address')}  ${w.address || '—'}`);
    console.log(`  ${muted('balance')}  ${mint('$' + (w.usdcBalance ?? '0') + ' USDC')}\n`);
  } catch (e) {
    sp.stop();
    console.log(red(`  ${e.message}`));
  }
}

async function cmdStats() {
  const sp = spinner('fetching live traction…');
  try {
    const s = await api('/api/stats');
    sp.stop();
    const np = s.nanopayments && typeof s.nanopayments === 'object' ? s.nanopayments.count : s.nanopayments;
    console.log(`\n  ${grad('Puls — live on Arc')}\n`);
    const row = (k, v) => console.log(`  ${muted(k.padEnd(22))} ${BOLD}${v}${RESET}`);
    row('Trades', fmt(s.trades));
    row('USDC volume', '$' + fmt(s.volumeUsdc));
    row('Markets deployed', fmt(s.marketsDeployed));
    row('Autonomous agents', fmt(s.agents));
    row('Agent trades', fmt(s.agentTrades));
    row('x402 nanopayments', fmt(np));
    row('Wallets', fmt(s.users));
    console.log('');
  } catch (e) {
    sp.stop();
    console.log(red(`  ${e.message}`));
  }
}

async function cmdMarkets() {
  const sp = spinner('loading markets…');
  try {
    const list = await api('/api/markets?limit=12');
    sp.stop();
    const markets = Array.isArray(list) ? list : list.markets || [];
    console.log(`\n  ${grad('Live markets')}\n`);
    for (const m of markets.slice(0, 12)) {
      const yes = m.yesPrice ?? m.priceYes ?? m.yes ?? null;
      const odds = yes != null ? `${Math.round(Number(yes) * 100)}¢` : '';
      console.log(`  ${pink('•')} ${(m.question || m.title || m.slug || '').slice(0, 64)}`);
      if (odds || m.slug) console.log(`    ${muted((m.slug || '').slice(0, 48))}  ${mint(odds)}`);
    }
    console.log('');
  } catch (e) {
    sp.stop();
    console.log(red(`  ${e.message}`));
  }
}

async function cmdFeed() {
  console.log(`\n  ${grad('Live trades')} ${muted('(ctrl+c to stop)')}\n`);
  const seen = new Set();
  let first = true;
  async function tick() {
    try {
      const list = await api('/api/trade/recent?limit=8');
      const trades = Array.isArray(list) ? list : [];
      for (const t of trades.reverse()) {
        const id = t.tx_id || t.txId || `${t.question}-${t.usdc_amount}-${t.created_at}`;
        if (seen.has(id)) continue;
        seen.add(id);
        if (first) continue; // don't dump history on first poll
        const side = (t.side || '').toUpperCase();
        const sc = side === 'YES' ? ok(side.padEnd(3)) : red(side.padEnd(3));
        const amt = '$' + (t.usdc_amount ?? t.amount ?? 0);
        console.log(`  ${sc} ${mint(amt.padEnd(8))} ${(t.question || '').slice(0, 56)}`);
      }
      first = false;
    } catch {}
  }
  await tick();
  first = false;
  setInterval(tick, 4000);
  await new Promise(() => {}); // run until ctrl+c
}

async function cmdOracle(slug) {
  if (!slug) {
    console.log(muted('  Usage: puls oracle <market-slug>   (get a slug from `puls markets`)'));
    return;
  }
  const sp = spinner('asking the AI swarm…');
  try {
    const o = await api(`/api/oracle/${encodeURIComponent(slug)}`);
    sp.stop();
    const ai = Math.round((o.aiYes ?? o.ai ?? 0) * 100);
    const crowd = Math.round((o.crowdYes ?? o.crowd ?? 0) * 100);
    console.log(`\n  ${grad('AI Oracle vs the crowd')}\n`);
    console.log(`  ${muted('🤖 AI swarm   ')} ${bar(ai)} ${BOLD}${ai}%${RESET}`);
    console.log(`  ${muted('👥 Crowd      ')} ${bar(crowd)} ${BOLD}${crowd}%${RESET}\n`);
  } catch (e) {
    sp.stop();
    console.log(red(`  ${e.message}`));
  }
}
function bar(pct) {
  const n = Math.round((pct / 100) * 20);
  let s = '';
  for (let i = 0; i < 20; i++) {
    const [r, g, b] = gradAt(i / 19);
    s += i < n ? `${fg(r, g, b)}█` : `${DIM}░`;
  }
  return s + RESET;
}

async function cmdChat() {
  const key = loadCfg().key;
  if (!key) {
    console.log(red('  Not logged in.') + muted('  Run:  puls login pk_live_…'));
    console.log(muted(`  Generate a key at ${APP_URL} → Profile → API Keys.`));
    return;
  }
  console.log(`\n  ${grad('Chat with your Puls agent')}  ${muted('— type a message, or "exit"')}`);
  console.log(muted('  It can research, reason with sources, and trade real USDC within its budget.\n'));
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const ask = () =>
    new Promise((resolve) => rl.question(`  ${pink('you ›')} `, resolve));
  while (true) {
    const msg = (await ask()).trim();
    if (!msg) continue;
    if (['exit', 'quit', ':q', 'q'].includes(msg.toLowerCase())) break;
    const sp = spinner('agent is thinking…');
    try {
      const r = await api('/api/agent/chat', { method: 'POST', body: { message: msg }, auth: true });
      sp.stop();
      const reply = (r.reply || '').trim() || '…';
      console.log(`  ${grad('agent ›')} ${reply}`);
      if (r.trade) {
        const t = r.trade;
        console.log(
          `    ${ok('⚡ traded')} ${BOLD}${t.side} $${t.usdcAmount}${RESET} ${muted('on')} ${t.slug}` +
            (t.txHash ? `\n    ${muted('tx')} https://testnet.arcscan.app/tx/${t.txHash}` : ''),
        );
      }
      if (Array.isArray(r.sources) && r.sources.length) {
        console.log(muted('    sources:'));
        for (const s of r.sources.slice(0, 3)) {
          const u = typeof s === 'string' ? s : s.url || s.link || '';
          const ttl = typeof s === 'string' ? '' : s.title || '';
          if (u) console.log(muted(`      • ${ttl ? ttl.slice(0, 50) + ' — ' : ''}${u}`));
        }
      }
      if (r.remaining != null) console.log(muted(`    budget left: $${r.remaining}`));
      console.log('');
    } catch (e) {
      sp.stop();
      if (/not started/i.test(e.message)) {
        console.log(red('  Your agent isn’t started yet.'));
        console.log(muted(`  Open ${APP_URL} → My Agent → fund & start it, then come back.\n`));
      } else {
        console.log(red(`  ${e.message}\n`));
      }
    }
  }
  rl.close();
  console.log(muted('\n  later 👋\n'));
}

function help() {
  const cmd = (c, d) => console.log(`  ${pink(c.padEnd(20))} ${muted(d)}`);
  console.log(`\n  ${grad('Puls CLI')} ${muted('— the market for what happens next\n')}`);
  cmd('puls login <key>', 'save your API key (Profile → API Keys)');
  cmd('puls chat', 'chat with your AI agent (trades real USDC)');
  cmd('puls markets', 'live prediction markets');
  cmd('puls feed', 'live trade stream');
  cmd('puls oracle <slug>', 'AI swarm vs the crowd on a market');
  cmd('puls stats', 'platform traction');
  cmd('puls whoami', 'your wallet + balance');
  cmd('puls logout', 'remove your saved key');
  console.log(`\n  ${muted('API:')} ${API}   ${muted('docs:')} https://docs.pulsmarket.tech\n`);
}

// ── main ─────────────────────────────────────────────────────────────────────
async function main() {
  const [cmd, ...rest] = process.argv.slice(2);

  // Default (no command) and `chat` launch the full interactive TUI.
  if (!cmd || cmd === 'chat') {
    if (process.stdin.isTTY && process.stdout.isTTY && !process.env.PULS_NO_TUI) {
      const { startTui } = await import('./tui.mjs');
      return startTui();
    }
    await intro();
    help();
    return;
  }

  if (cmd === 'help' || cmd === '-h' || cmd === '--help') {
    await intro();
    help();
    if (!loadCfg().key) console.log(muted(`  Not logged in — generate a key at ${APP_URL} → Profile → API Keys.\n`));
    return;
  }

  switch (cmd) {
    case 'login':
      return cmdLogin(rest[0]);
    case 'logout':
      return cmdLogout();
    case 'whoami':
      return cmdWhoami();
    case 'chat':
      return cmdChat();
    case 'markets':
      return cmdMarkets();
    case 'feed':
      return cmdFeed();
    case 'oracle':
      return cmdOracle(rest[0]);
    case 'stats':
      return cmdStats();
    default:
      console.log(red(`  Unknown command: ${cmd}`));
      help();
  }
}

function prompt(q) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolve) => rl.question(q, (a) => { rl.close(); resolve(a); }));
}

process.on('SIGINT', () => {
  showCursor();
  console.log(muted('\n  bye 👋'));
  process.exit(0);
});

main().then(
  () => {},
  (e) => {
    showCursor();
    console.error(red(`\n  ${e.message}\n`));
    process.exit(1);
  },
);
