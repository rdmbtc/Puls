// Shared Puls API + config (used by the TUI and the one-shot commands).
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export const API = (process.env.PULS_API || 'https://api.pulsmarket.tech').replace(/\/+$/, '');
export const APP_URL = 'https://app.pulsmarket.tech';
export const DOCS_URL = 'https://docs.pulsmarket.tech';

const CFG_DIR = join(homedir(), '.puls');
const CFG_FILE = join(CFG_DIR, 'config.json');

export function loadCfg() {
  try {
    return JSON.parse(readFileSync(CFG_FILE, 'utf8'));
  } catch {
    return {};
  }
}
export function saveCfg(cfg) {
  if (!existsSync(CFG_DIR)) mkdirSync(CFG_DIR, { recursive: true });
  writeFileSync(CFG_FILE, JSON.stringify(cfg, null, 2), { mode: 0o600 });
}
export function clearCfg() {
  try {
    if (existsSync(CFG_FILE)) rmSync(CFG_FILE);
  } catch {}
}
export const isAuthed = () => !!loadCfg().key;

export async function api(path, { method = 'GET', body, key } = {}) {
  const headers = { accept: 'application/json' };
  if (body) headers['content-type'] = 'application/json';
  const k = key ?? loadCfg().key;
  if (k) headers.authorization = `Bearer ${k}`;
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

// Endpoints
export const apiWithKey = (path, body, key) => api(path, { method: 'POST', body, key });
export const getStats = () => api('/api/stats');
export const getMarkets = async (n = 12) => {
  const l = await api(`/api/markets?limit=${n}`);
  return Array.isArray(l) ? l : l.markets || [];
};
export const getRecent = async (n = 8) => {
  const l = await api(`/api/trade/recent?limit=${n}`);
  return Array.isArray(l) ? l : [];
};
export const getOracle = (slug) => api(`/api/oracle/${encodeURIComponent(slug)}`);
export const getWallet = () => api('/api/wallet/get-or-create', { method: 'POST', body: {} });
export const agentChat = (message) =>
  api('/api/agent/chat', { method: 'POST', body: { message } });

export const fmtNum = (n) => (Number(n) || 0).toLocaleString('en-US');
