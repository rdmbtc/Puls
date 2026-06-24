// Puls TUI — an interactive terminal app (Ink/React): looping animated banner,
// slash-command autocomplete, live agent chat. Rendered only on a TTY.
import React, { useState, useEffect, useMemo, useRef } from 'react';
import { render, Box, Text, useApp, useInput } from 'ink';
import TextInput from 'ink-text-input';
import Spinner from 'ink-spinner';
import htm from 'htm';
import * as lib from './lib.mjs';

const html = htm.bind(React.createElement);

const PINK = '#EC4899';
const MINT = '#2DD4BF';
const GREEN = '#22C55E';
const RED = '#F87171';

const BANNER_ROWS = [
  '██████╗ ██╗   ██╗██╗     ███████╗',
  '██╔══██╗██║   ██║██║     ██╔════╝',
  '██████╔╝██║   ██║██║     ███████╗',
  '██╔═══╝ ██║   ██║██║     ╚════██║',
  '██║     ╚██████╔╝███████╗███████║',
  '╚═╝      ╚═════╝ ╚══════╝╚══════╝',
];
const BW = Math.max(...BANNER_ROWS.map((r) => [...r].length));
const WAVE = '▁▂▃▄▅▆▇█▇▆▅▄▃▂▁';

// gradient pink → pink-light → mint
const STOPS = [
  [236, 72, 153],
  [244, 114, 182],
  [45, 212, 191],
];
const lerp = (a, b, t) => Math.round(a + (b - a) * t);
const toHex = (n) => Math.max(0, Math.min(255, n)).toString(16).padStart(2, '0');
function gradAt(t) {
  t = Math.max(0, Math.min(1, t));
  const seg = t * (STOPS.length - 1);
  const i = Math.min(STOPS.length - 2, Math.floor(seg));
  const f = seg - i;
  const [r1, g1, b1] = STOPS[i];
  const [r2, g2, b2] = STOPS[i + 1];
  return [lerp(r1, r2, f), lerp(g1, g2, f), lerp(b1, b2, f)];
}
/** Per-column color: a flowing gradient + a bright shimmer band that loops. */
function colorFor(t, frame) {
  let [r, g, b] = gradAt((t + frame * 0.012) % 1); // slow gradient drift
  const band = ((frame * 0.045) % 1.5) - 0.25; // bright sweep, loops with a gap
  const d = Math.abs(t - band);
  if (d < 0.1) {
    const k = (1 - d / 0.1) * 0.9;
    r = lerp(r, 255, k);
    g = lerp(g, 255, k);
    b = lerp(b, 255, k);
  }
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

const COMMANDS = [
  { name: 'markets', desc: 'live prediction markets' },
  { name: 'feed', desc: 'live trade stream' },
  { name: 'oracle', desc: 'AI swarm vs the crowd  ·  /oracle <slug>' },
  { name: 'stats', desc: 'platform traction' },
  { name: 'whoami', desc: 'your wallet + balance' },
  { name: 'login', desc: 'save your API key  ·  /login pk_live_…' },
  { name: 'logout', desc: 'remove your saved key' },
  { name: 'stop', desc: 'stop the live feed' },
  { name: 'clear', desc: 'clear the screen' },
  { name: 'help', desc: 'show all commands' },
  { name: 'exit', desc: 'quit' },
];

let _id = 0;
const nextId = () => `m${_id++}`;

function Banner({ frame }) {
  return html`
    <${Box} flexDirection="column">
      ${BANNER_ROWS.map(
        (row, ri) => html`
          <${Box} key=${ri}>
            ${[...row].map((ch, ci) => {
              const t = BW <= 1 ? 0 : ci / (BW - 1);
              return html`<${Text} key=${ci} color=${colorFor(t, frame)}>${ch}</${Text}>`;
            })}
          </${Box}>
        `,
      )}
    </${Box}>
  `;
}

function Wave({ frame }) {
  const head = Math.floor((frame * 0.9) % (BW + WAVE.length));
  const chars = [];
  for (let i = 0; i < BW; i++) {
    const d = head - i;
    chars.push(d >= 0 && d < WAVE.length ? WAVE[d] : '─');
  }
  const t = ((frame * 0.045) % 1.5) - 0.25;
  // colour the whole wave with one flowing mint→pink tone (cheap: one Text)
  const [r, g, b] = gradAt((0.5 + frame * 0.012) % 1);
  return html`<${Text} color=${`#${toHex(r)}${toHex(g)}${toHex(b)}`}>${chars.join('')}</${Text}>`;
}

const MessageView = React.memo(function MessageView({ item }) {
  if (item.role === 'user') {
    return html`<${Box}><${Text} color=${PINK} bold>you › </${Text}><${Text}>${item.text}</${Text}></${Box}>`;
  }
  if (item.role === 'agent') {
    return html`
      <${Box} flexDirection="column">
        <${Box}><${Text} color=${MINT} bold>agent › </${Text}><${Text}>${item.text}</${Text}></${Box}>
        ${item.trade &&
        html`<${Text} color=${GREEN}>   ⚡ traded ${item.trade.side} $${item.trade.usdcAmount} on ${item.trade.slug}${item.trade.txHash ? `  ·  arcscan.app/tx/${String(item.trade.txHash).slice(0, 10)}…` : ''}</${Text}>`}
        ${Array.isArray(item.sources) && item.sources.length > 0 &&
        html`<${Box} flexDirection="column">${item.sources.slice(0, 3).map((s, i) => {
          const u = typeof s === 'string' ? s : s.url || s.link || '';
          const ttl = typeof s === 'string' ? '' : s.title || '';
          return html`<${Text} key=${i} color="gray">   • ${ttl ? String(ttl).slice(0, 46) + ' — ' : ''}${u}</${Text}>`;
        })}</${Box}>`}
        ${item.remaining != null && html`<${Text} color="gray">   budget left: $${item.remaining}</${Text}>`}
      </${Box}>
    `;
  }
  if (item.role === 'err') {
    return html`<${Box}><${Text} color=${RED}>✗ ${item.text}</${Text}></${Box}>`;
  }
  if (item.role === 'markets') {
    return html`
      <${Box} flexDirection="column">
        <${Text} color=${MINT} bold>live markets</${Text}>
        ${item.items.slice(0, 10).map((m, i) => {
          const yes = m.yesPrice ?? m.priceYes ?? m.yes ?? null;
          const odds = yes != null ? `${Math.round(Number(yes) * 100)}¢` : '';
          return html`<${Box} key=${i}><${Text} color=${PINK}>  • </${Text}><${Text}>${String(m.question || m.title || m.slug || '').slice(0, 56)} </${Text}><${Text} color=${MINT}>${odds}</${Text}></${Box}>`;
        })}
      </${Box}>
    `;
  }
  if (item.role === 'trade') {
    const yes = item.side === 'YES';
    return html`<${Box}><${Text} color=${yes ? GREEN : RED}>  ${item.side.padEnd(3)} </${Text}><${Text} color=${MINT}>$${item.amount} </${Text}><${Text} color="gray">${String(item.question).slice(0, 50)}</${Text}></${Box}>`;
  }
  return html`<${Box}><${Text} color="gray">${item.text}</${Text}></${Box}>`;
});

function App() {
  const { exit } = useApp();
  const [msgs, setMsgs] = useState([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [busyLabel, setBusyLabel] = useState('thinking');
  const [authed, setAuthed] = useState(lib.isAuthed());
  const [balance, setBalance] = useState(null);
  const [frame, setFrame] = useState(0);
  const [sel, setSel] = useState(0);
  const feedRef = useRef(null);
  const seenRef = useRef(new Set());

  const add = (m) => setMsgs((p) => [...p, { id: nextId(), ...m }]);

  useEffect(() => {
    add({
      role: 'sys',
      text: lib.isAuthed()
        ? 'Connected. Ask your agent anything, or type / for commands.'
        : `Not logged in. Type /login pk_live_…  (key at ${lib.APP_URL} → Profile → API Keys), or explore /markets · /stats.`,
    });
    if (lib.isAuthed()) lib.getWallet().then((w) => setBalance(w.usdcBalance)).catch(() => {});
    const t = setInterval(() => setFrame((f) => (f + 1) % 100000), 90); // looping banner
    return () => {
      clearInterval(t);
      if (feedRef.current) clearInterval(feedRef.current);
    };
  }, []);

  // slash-command autocomplete
  const token =
    input.startsWith('/') && !/\s/.test(input) ? input.slice(1).toLowerCase() : null;
  const suggestions = useMemo(
    () => (token !== null ? COMMANDS.filter((c) => c.name.startsWith(token)) : []),
    [token],
  );
  const showDrop = !busy && suggestions.length > 0;
  useEffect(() => setSel(0), [token]);

  useInput((inp, key) => {
    if (showDrop) {
      if (key.upArrow) return setSel((s) => (s - 1 + suggestions.length) % suggestions.length);
      if (key.downArrow) return setSel((s) => (s + 1) % suggestions.length);
      if (key.tab) return setInput('/' + suggestions[Math.min(sel, suggestions.length - 1)].name + ' ');
    }
    if (key.escape && feedRef.current) stopFeed();
  });

  async function withBusy(label, fn) {
    setBusyLabel(label);
    setBusy(true);
    try {
      await fn();
    } catch (e) {
      add({ role: 'err', text: `${e.message}` });
    } finally {
      setBusy(false);
    }
  }

  function startFeed() {
    if (feedRef.current) return add({ role: 'sys', text: 'feed already running. /stop or Esc to end it.' });
    add({ role: 'sys', text: 'live trades — /stop or Esc to end' });
    lib
      .getRecent(8)
      .then((ts) => ts.forEach((t) => seenRef.current.add(t.tx_id || t.txId || `${t.question}-${t.usdc_amount}-${t.created_at}`)))
      .catch(() => {});
    feedRef.current = setInterval(async () => {
      try {
        const trades = await lib.getRecent(8);
        for (const t of trades.reverse()) {
          const id = t.tx_id || t.txId || `${t.question}-${t.usdc_amount}-${t.created_at}`;
          if (seenRef.current.has(id)) continue;
          seenRef.current.add(id);
          add({ role: 'trade', side: String(t.side || '').toUpperCase(), amount: t.usdc_amount ?? t.amount ?? 0, question: t.question || '' });
        }
      } catch {}
    }, 4000);
  }
  function stopFeed() {
    if (feedRef.current) {
      clearInterval(feedRef.current);
      feedRef.current = null;
      add({ role: 'sys', text: 'feed stopped.' });
    }
  }

  async function runCmd(line) {
    const [c, ...args] = line.slice(1).split(/\s+/);
    const cmd = (c || '').toLowerCase();
    switch (cmd) {
      case 'help':
        add({ role: 'sys', text: 'commands:' });
        for (const cc of COMMANDS) add({ role: 'sys', text: `  /${cc.name.padEnd(10)} ${cc.desc}` });
        return;
      case 'clear':
        seenRef.current = new Set();
        return setMsgs([]);
      case 'exit':
      case 'quit':
        return exit();
      case 'login': {
        const key = args[0];
        if (!key || !key.startsWith('pk_')) return add({ role: 'err', text: 'Usage: /login pk_live_…' });
        return withBusy('verifying key', async () => {
          const w = await lib.apiWithKey('/api/wallet/get-or-create', {}, key);
          lib.saveCfg({ ...lib.loadCfg(), key });
          setAuthed(true);
          setBalance(w.usdcBalance);
          add({ role: 'sys', text: `✓ logged in · wallet ${w.address} · $${w.usdcBalance} USDC` });
        });
      }
      case 'logout':
        lib.clearCfg();
        setAuthed(false);
        setBalance(null);
        return add({ role: 'sys', text: 'logged out.' });
      case 'whoami':
        return withBusy('reading wallet', async () => {
          const w = await lib.getWallet();
          setBalance(w.usdcBalance);
          add({ role: 'sys', text: `wallet ${w.address} · $${w.usdcBalance} USDC` });
        });
      case 'stats':
        return withBusy('fetching stats', async () => {
          const s = await lib.getStats();
          const np = s.nanopayments && typeof s.nanopayments === 'object' ? s.nanopayments.count : s.nanopayments;
          add({ role: 'sys', text: `${lib.fmtNum(s.trades)} trades · $${lib.fmtNum(s.volumeUsdc)} vol · ${lib.fmtNum(s.marketsDeployed)} markets · ${lib.fmtNum(s.agents)} agents · ${lib.fmtNum(s.agentTrades)} agent trades · ${lib.fmtNum(np)} x402 · ${lib.fmtNum(s.users)} wallets` });
        });
      case 'markets':
        return withBusy('loading markets', async () => add({ role: 'markets', items: await lib.getMarkets(10) }));
      case 'oracle': {
        const slug = args[0];
        if (!slug) return add({ role: 'err', text: 'Usage: /oracle <market-slug>  (get one from /markets)' });
        return withBusy('asking the swarm', async () => {
          const o = await lib.getOracle(slug);
          add({ role: 'sys', text: `🤖 AI swarm ${Math.round((o.aiYes ?? o.ai ?? 0) * 100)}%  vs  👥 crowd ${Math.round((o.crowdYes ?? o.crowd ?? 0) * 100)}%` });
        });
      }
      case 'feed':
        return startFeed();
      case 'stop':
        return stopFeed();
      default:
        return add({ role: 'err', text: `unknown command: /${cmd}. try /help` });
    }
  }

  async function onSubmit(value) {
    const v = (value || '').trim();
    setInput('');
    if (!v || busy) return;
    if (v.startsWith('/')) {
      if (!/\s/.test(v)) {
        const tk = v.slice(1).toLowerCase();
        const exact = COMMANDS.find((c) => c.name === tk);
        const chosen = exact ? exact.name : suggestions[Math.min(sel, Math.max(0, suggestions.length - 1))]?.name;
        if (chosen) return runCmd('/' + chosen);
      }
      return runCmd(v);
    }
    if (!lib.isAuthed()) return add({ role: 'err', text: 'Log in first: /login pk_live_…  (app → Profile → API Keys).' });
    add({ role: 'user', text: v });
    await withBusy('agent is thinking', async () => {
      try {
        const r = await lib.agentChat(v);
        add({ role: 'agent', text: (r.reply || '…').trim(), trade: r.trade, sources: r.sources, remaining: r.remaining });
      } catch (e) {
        if (/not started/i.test(e.message)) add({ role: 'err', text: `Your agent isn't started yet — open ${lib.APP_URL} → My Agent → fund & start it.` });
        else throw e;
      }
    });
  }

  // windowed log (full-screen app: keep the most recent that fit)
  const rows = process.stdout.rows || 24;
  const logN = Math.max(5, rows - 16);
  const logEls = useMemo(
    () => msgs.slice(-logN).map((m) => html`<${MessageView} key=${m.id} item=${m} />`),
    [msgs, logN],
  );

  return html`
    <${Box} flexDirection="column" paddingX=${1}>
      <${Banner} frame=${frame} />
      <${Box}><${Wave} frame=${frame} /></${Box}>
      <${Box} marginBottom=${1}>
        <${Text} color="gray">the market for what happens next  ·  </${Text}>
        <${Text} color=${authed ? GREEN : 'gray'}>${authed ? '● connected' : '○ guest'}</${Text}>
        ${balance != null && html`<${Text} color="gray">  ·  $${balance} USDC</${Text}>`}
      </${Box}>

      <${Box} flexDirection="column">${logEls}</${Box}>

      ${showDrop &&
      html`<${Box} flexDirection="column" marginTop=${1}>
        ${suggestions.map((s, i) => {
          const on = i === Math.min(sel, suggestions.length - 1);
          return html`<${Box} key=${s.name}>
            <${Text} color=${on ? MINT : 'gray'}>${on ? '❯ ' : '  '}</${Text}>
            <${Text} color=${on ? 'white' : 'gray'} bold=${on}>/${s.name.padEnd(10)}</${Text}>
            <${Text} color="gray"> ${s.desc}</${Text}>
          </${Box}>`;
        })}
        <${Text} color="gray">  ↑↓ select · Tab complete · Enter run</${Text}>
      </${Box}>`}

      ${busy
        ? html`<${Box} marginTop=${1}><${Text} color=${MINT}><${Spinner} type="dots" /></${Text}><${Text} color="gray"> ${busyLabel}…</${Text}></${Box}>`
        : html`<${Box} marginTop=${showDrop ? 0 : 1} borderStyle="round" borderColor=${PINK} paddingX=${1}>
            <${Text} color=${PINK} bold>› </${Text}>
            <${TextInput} value=${input} onChange=${setInput} onSubmit=${onSubmit} placeholder="Ask your agent, or type / for commands" />
          </${Box}>`}

      <${Box}><${Text} color="gray">  /help · /exit${feedRef.current ? ' · Esc stops feed' : ''}</${Text}></${Box}>
    </${Box}>
  `;
}

export function startTui() {
  render(html`<${App} />`);
}
