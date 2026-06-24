// Puls TUI — an interactive terminal app (Ink/React) to chat with your agent
// and watch the live market. Rendered only when stdin is a TTY (see puls.mjs).
import React, { useState, useEffect, useMemo, useRef } from 'react';
import { render, Box, Text, useApp, useInput, Static } from 'ink';
import TextInput from 'ink-text-input';
import Spinner from 'ink-spinner';
import Gradient from 'ink-gradient';
import htm from 'htm';
import * as lib from './lib.mjs';

const html = htm.bind(React.createElement);

const PINK = '#EC4899';
const MINT = '#2DD4BF';
const AMBER = '#F59E0B';
const GREEN = '#22C55E';
const RED = '#F87171';
const GRAD = [PINK, '#F472B6', MINT];

const BANNER = [
  '██████╗ ██╗   ██╗██╗     ███████╗',
  '██╔══██╗██║   ██║██║     ██╔════╝',
  '██████╔╝██║   ██║██║     ███████╗',
  '██╔═══╝ ██║   ██║██║     ╚════██║',
  '██║     ╚██████╔╝███████╗███████║',
  '╚═╝      ╚═════╝ ╚══════╝╚══════╝',
].join('\n');

const HELP = [
  ['/chat <msg>', 'talk to your agent (or just type — no slash needed)'],
  ['/markets', 'live prediction markets'],
  ['/feed', 'live trade stream  ·  /stop to end it'],
  ['/oracle <slug>', 'AI swarm vs the crowd'],
  ['/stats', 'platform traction'],
  ['/whoami', 'your wallet + balance'],
  ['/login <key>', 'save your API key (app → Profile → API Keys)'],
  ['/logout', 'remove your saved key'],
  ['/clear', 'clear the screen'],
  ['/exit', 'quit'],
];

let _id = 0;
const nextId = () => `m${_id++}`;

function MessageView({ item }) {
  if (item.role === 'header') {
    return html`
      <${Box} flexDirection="column" marginBottom=${1}>
        <${Gradient} colors=${GRAD}><${Text}>${BANNER}</${Text}><//>
        <${Box} marginTop=${1}>
          <${Text} color="gray">  the market for what happens next  ·  </${Text}>
          <${Text} color=${MINT}>${lib.API.replace('https://', '')}</${Text}>
        </${Box}>
      </${Box}>
    `;
  }
  if (item.role === 'user') {
    return html`<${Box}><${Text} color=${PINK} bold>you › </${Text}><${Text}>${item.text}</${Text}></${Box}>`;
  }
  if (item.role === 'agent') {
    return html`
      <${Box} flexDirection="column" marginY=${0}>
        <${Box}><${Text} color=${MINT} bold>agent › </${Text}><${Text}>${item.text}</${Text}></${Box}>
        ${item.trade &&
        html`<${Text} color=${GREEN}>   ⚡ traded ${item.trade.side} $${item.trade.usdcAmount} on ${item.trade.slug}${item.trade.txHash ? `  ·  arcscan.app/tx/${String(item.trade.txHash).slice(0, 10)}…` : ''}</${Text}>`}
        ${Array.isArray(item.sources) && item.sources.length > 0 &&
        html`<${Box} flexDirection="column">${item.sources.slice(0, 3).map((s, i) => {
          const u = typeof s === 'string' ? s : s.url || s.link || '';
          const ttl = typeof s === 'string' ? '' : s.title || '';
          return html`<${Text} key=${i} color="gray">   • ${ttl ? String(ttl).slice(0, 48) + ' — ' : ''}${u}</${Text}>`;
        })}</${Box}>`}
        ${item.remaining != null &&
        html`<${Text} color="gray">   budget left: $${item.remaining}</${Text}>`}
      </${Box}>
    `;
  }
  if (item.role === 'err') {
    return html`<${Box}><${Text} color=${RED}>✗ </${Text}><${Text} color=${RED}>${item.text}</${Text}></${Box}>`;
  }
  if (item.role === 'markets') {
    return html`
      <${Box} flexDirection="column" marginY=${0}>
        <${Text} color=${MINT} bold>live markets</${Text}>
        ${item.items.slice(0, 12).map((m, i) => {
          const yes = m.yesPrice ?? m.priceYes ?? m.yes ?? null;
          const odds = yes != null ? `${Math.round(Number(yes) * 100)}¢` : '';
          return html`<${Box} key=${i}>
            <${Text} color=${PINK}>  • </${Text}>
            <${Text}>${String(m.question || m.title || m.slug || '').slice(0, 58)} </${Text}>
            <${Text} color=${MINT}>${odds}</${Text}>
          </${Box}>`;
        })}
      </${Box}>
    `;
  }
  if (item.role === 'trade') {
    const yes = item.side === 'YES';
    return html`<${Box}>
      <${Text} color=${yes ? GREEN : RED}>  ${item.side.padEnd(3)} </${Text}>
      <${Text} color=${MINT}>$${item.amount} </${Text}>
      <${Text} color="gray">${String(item.question).slice(0, 52)}</${Text}>
    </${Box}>`;
  }
  // sys
  return html`<${Box}><${Text} color="gray">${item.text}</${Text}></${Box}>`;
}

function App() {
  const { exit } = useApp();
  const [msgs, setMsgs] = useState([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [busyLabel, setBusyLabel] = useState('thinking');
  const [authed, setAuthed] = useState(lib.isAuthed());
  const [balance, setBalance] = useState(null);
  const feedRef = useRef(null);
  const seenRef = useRef(new Set());

  const add = (m) => setMsgs((p) => [...p, { id: nextId(), ...m }]);

  useEffect(() => {
    add({
      role: 'sys',
      text: lib.isAuthed()
        ? 'Connected. Ask your agent anything, or type /help.'
        : `Not logged in. Run /login pk_live_…  (get a key at ${lib.APP_URL} → Profile → API Keys), or explore: /markets  /stats.`,
    });
    if (lib.isAuthed()) lib.getWallet().then((w) => setBalance(w.usdcBalance)).catch(() => {});
    return () => feedRef.current && clearInterval(feedRef.current);
  }, []);

  useInput((input, key) => {
    if (key.escape) {
      if (feedRef.current) {
        clearInterval(feedRef.current);
        feedRef.current = null;
        add({ role: 'sys', text: 'feed stopped.' });
      }
    }
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
    if (feedRef.current) return add({ role: 'sys', text: 'feed already running. /stop to end it.' });
    add({ role: 'sys', text: 'live trades — /stop or Esc to end' });
    const tick = async () => {
      try {
        const trades = await lib.getRecent(8);
        for (const t of trades.reverse()) {
          const id = t.tx_id || t.txId || `${t.question}-${t.usdc_amount}-${t.created_at}`;
          if (seenRef.current.has(id)) continue;
          seenRef.current.add(id);
          add({
            role: 'trade',
            side: String(t.side || '').toUpperCase(),
            amount: t.usdc_amount ?? t.amount ?? 0,
            question: t.question || '',
          });
        }
      } catch {}
    };
    // prime the seen-set silently, then stream new ones
    lib.getRecent(8).then((ts) => ts.forEach((t) => seenRef.current.add(t.tx_id || t.txId || `${t.question}-${t.usdc_amount}-${t.created_at}`))).catch(() => {});
    feedRef.current = setInterval(tick, 4000);
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
        for (const [k, d] of HELP) add({ role: 'sys', text: `  ${k.padEnd(16)} ${d}` });
        return;
      case 'clear':
        seenRef.current = new Set();
        setMsgs([]);
        return;
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
          add({
            role: 'sys',
            text:
              `${lib.fmtNum(s.trades)} trades · $${lib.fmtNum(s.volumeUsdc)} volume · ${lib.fmtNum(s.marketsDeployed)} markets · ` +
              `${lib.fmtNum(s.agents)} agents · ${lib.fmtNum(s.agentTrades)} agent trades · ${lib.fmtNum(np)} x402 payments · ${lib.fmtNum(s.users)} wallets`,
          });
        });
      case 'markets':
        return withBusy('loading markets', async () => {
          const m = await lib.getMarkets(12);
          add({ role: 'markets', items: m });
        });
      case 'oracle': {
        const slug = args[0];
        if (!slug) return add({ role: 'err', text: 'Usage: /oracle <market-slug>  (get one from /markets)' });
        return withBusy('asking the swarm', async () => {
          const o = await lib.getOracle(slug);
          const ai = Math.round((o.aiYes ?? o.ai ?? 0) * 100);
          const crowd = Math.round((o.crowdYes ?? o.crowd ?? 0) * 100);
          add({ role: 'sys', text: `🤖 AI swarm ${ai}%  vs  👥 crowd ${crowd}%` });
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
    if (v.startsWith('/')) return runCmd(v);
    if (!lib.isAuthed()) {
      return add({ role: 'err', text: 'Log in first: /login pk_live_…  (app → Profile → API Keys).' });
    }
    add({ role: 'user', text: v });
    await withBusy('agent is thinking', async () => {
      try {
        const r = await lib.agentChat(v);
        add({ role: 'agent', text: (r.reply || '…').trim(), trade: r.trade, sources: r.sources, remaining: r.remaining });
      } catch (e) {
        if (/not started/i.test(e.message)) {
          add({ role: 'err', text: `Your agent isn't started yet — open ${lib.APP_URL} → My Agent → fund & start it.` });
        } else {
          throw e;
        }
      }
    });
  }

  const items = useMemo(() => [{ id: '__hdr', role: 'header' }, ...msgs], [msgs]);

  return html`
    <${Box} flexDirection="column">
      <${Static} items=${items}>
        ${(item) => html`<${MessageView} key=${item.id} item=${item} />`}
      </${Static}>

      ${busy
        ? html`<${Box} marginTop=${1}><${Text} color=${MINT}><${Spinner} type="dots" /></${Text}><${Text} color="gray"> ${busyLabel}…</${Text}></${Box}>`
        : html`
          <${Box} marginTop=${1}>
            <${Text} color=${PINK} bold>› </${Text}>
            <${TextInput} value=${input} onChange=${setInput} onSubmit=${onSubmit} placeholder="Ask your agent, or /help" />
          </${Box}>`}

      <${Box} marginTop=${1}>
        <${Text} color="gray">${authed ? '● ' : '○ '}</${Text}>
        <${Text} color=${authed ? GREEN : 'gray'}>${authed ? 'connected' : 'guest'}</${Text}>
        ${balance != null && html`<${Text} color="gray">  ·  $${balance} USDC</${Text}>`}
        <${Text} color="gray">     /help · /exit · Esc stops feed</${Text}>
      </${Box}>
    </${Box}>
  `;
}

export function startTui() {
  render(html`<${App} />`);
}
