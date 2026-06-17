// ── Agent web research (keyless) ──────────────────────────────────────────────
//
// Gives the autonomous agent "eyes on the open internet" before it decides.
// Inspired by Agent-Reach's capability layer, but implemented as plain HTTP
// calls (no Python CLI, no cookies, no API keys, no risk to the prod backend):
//
//   search:  Jina Reader (r.jina.ai) over DuckDuckGo Lite — returns clean
//            markdown snippets (title · summary · source · date) for a query.
//   read:    Jina Reader (r.jina.ai) over any URL — clean markdown of a page.
//
// Both endpoints are free and keyless. This turns Pulse from a pure price
// arbitrageur into an agent that researches real-world signal before trading:
// it pulls fresh news/sentiment on the market question, feeds it to the LLM,
// and cites a source in its reasoning.
//
// Best-effort by design: any failure returns an empty result so the agent still
// trades — research enriches the decision, it never blocks it.

const JINA_READER = 'https://r.jina.ai/';
const DDG_LITE = 'https://lite.duckduckgo.com/lite/';
const RESEARCH_TIMEOUT_MS = parseInt(process.env.AGENT_RESEARCH_TIMEOUT_MS || '12000', 10);
const RESEARCH_ENABLED = String(process.env.AGENT_RESEARCH_ENABLED ?? 'true').toLowerCase() !== 'false';

async function fetchText(url, { timeoutMs = RESEARCH_TIMEOUT_MS, headers = {} } = {}) {
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const r = await fetch(url, {
      signal: ac.signal,
      headers: { 'User-Agent': 'Mozilla/5.0 (PulsAgent research)', Accept: 'text/plain, */*', ...headers },
    });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return await r.text();
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Parse the markdown Jina returns for a DuckDuckGo Lite results page into
 * structured { title, url, snippet, source } items.
 */
function parseDdgMarkdown(md, limit) {
  const results = [];
  // Lines like: "1.[Title](https://duckduckgo.com/l/?uddg=<encoded real url>...)"
  const re = /\d+\.\s*\[([^\]]+)\]\((https?:\/\/[^\)]+)\)/g;
  let m;
  while ((m = re.exec(md)) && results.length < limit) {
    const title = m[1].replace(/\*\*/g, '').trim();
    let url = m[2];
    // DDG wraps the real URL in ?uddg=<encoded>; unwrap it.
    const uddg = url.match(/[?&]uddg=([^&]+)/);
    if (uddg) { try { url = decodeURIComponent(uddg[1]); } catch (_) {} }
    if (/duckduckgo\.com\/(y\.js|l\/)/.test(url)) continue; // skip ad/redirect noise
    // The snippet is the text block after the link up to the next numbered item.
    const after = md.slice(m.index + m[0].length, m.index + m[0].length + 600);
    const snippet = after
      .split(/\n\d+\.\s*\[/)[0]
      .replace(/\*\*/g, '')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 280);
    let source = '';
    try { source = new URL(url).hostname.replace(/^www\./, ''); } catch (_) {}
    results.push({ title, url, snippet, source });
  }
  return results;
}

/**
 * Web search → top results for a query (keyless). Returns [] on any failure.
 * @param {string} query
 * @param {number} [limit=5]
 */
export async function webSearch(query, limit = 5) {
  if (!RESEARCH_ENABLED || !query) return [];
  try {
    const target = `${DDG_LITE}?q=${encodeURIComponent(query)}`;
    const md = await fetchText(`${JINA_READER}${target}`, { headers: { 'X-Respond-With': 'markdown' } });
    return parseDdgMarkdown(md, limit);
  } catch (e) {
    console.warn('[research] webSearch failed:', e.message);
    return [];
  }
}

/**
 * Read a single URL as clean markdown (keyless). Returns '' on failure.
 * @param {string} url
 * @param {number} [maxChars=4000]
 */
export async function readUrl(url, maxChars = 4000) {
  if (!RESEARCH_ENABLED || !url) return '';
  try {
    const md = await fetchText(`${JINA_READER}${url}`);
    return md.slice(0, maxChars);
  } catch (e) {
    console.warn('[research] readUrl failed:', e.message);
    return '';
  }
}

/**
 * Research a prediction-market question: search the open web and return a
 * compact brief the LLM can reason over, plus the cited sources.
 * Returns { brief, sources: [{title, url, source}] }.  Always safe.
 * @param {string} question
 */
export async function researchQuestion(question, limit = 4) {
  const hits = await webSearch(question, limit);
  if (hits.length === 0) return { brief: '', sources: [] };
  const brief = hits
    .map((h, i) => `[${i + 1}] ${h.title} (${h.source})\n${h.snippet}`)
    .join('\n\n')
    .slice(0, 1600);
  const sources = hits.map((h) => ({ title: h.title, url: h.url, source: h.source }));
  return { brief, sources };
}
