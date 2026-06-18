// ── Token swap (Circle App Kit) — USDC <-> EURC on Arc Testnet ────────────────
//
// Real on-chain swap via Circle's App Kit Swap capability, executed from the
// user's own Circle MPC wallet (SCA). This adds a stablecoin FX rail on top of
// the prediction-market economy: a user (or agent) holding EURC can swap to USDC
// to trade, and vice-versa — all settled on Arc, gasless.
//
// Notes from Circle docs:
//   - SCA wallets require allowanceStrategy: 'approve' (USDC permit sigs use
//     ecrecover, which doesn't accept the SCA's ERC-1271 signature).
//   - Arc Testnet swap liquidity can be thin; we always estimate first and
//     surface a clear error if a quote reverts.
//   - Needs KIT_KEY (free, Circle Console) in addition to API key + entity secret.
//
// Routes:
//   GET  /api/swap/config                  { enabled, tokens }
//   POST /api/swap/estimate { tokenIn, tokenOut, amountIn }  (verified)
//   POST /api/swap          { tokenIn, tokenOut, amountIn }  (verified) -> executes
//
// Wiring (server.js):
//   import { registerSwap } from './lib/swap.js';
//   registerSwap(app, { getWalletInfo, getWalletId, authenticateUser, requireVerifiedUser, strictLimiter });

const SWAP_TOKENS = ['USDC', 'EURC'];
const KIT_KEY = (process.env.KIT_KEY || '').trim();
const SWAP_ENABLED = Boolean(KIT_KEY) && String(process.env.SWAP_ENABLED ?? 'true').toLowerCase() !== 'false';

// Lazily import App Kit so the server still boots if the package/key is absent.
let _kit = null;
let _adapter = null;
async function getKit() {
  if (_kit && _adapter) return { kit: _kit, adapter: _adapter };
  const { AppKit } = await import('@circle-fin/app-kit');
  const { createCircleWalletsAdapter } = await import('@circle-fin/adapter-circle-wallets');
  _kit = new AppKit();
  _adapter = createCircleWalletsAdapter({
    apiKey: (process.env.CIRCLE_API_KEY || '').trim(),
    entitySecret: (process.env.CIRCLE_ENTITY_SECRET || '').trim(),
  });
  return { kit: _kit, adapter: _adapter };
}

export function registerSwap(app, deps) {
  const { getWalletInfo, getWalletId, authenticateUser, requireVerifiedUser, strictLimiter } = deps;

  app.get('/api/swap/config', (_req, res) => {
    res.json({ enabled: SWAP_ENABLED, tokens: SWAP_TOKENS, chain: 'Arc_Testnet' });
  });

  function validate(body) {
    const tokenIn = String(body.tokenIn || '').toUpperCase();
    const tokenOut = String(body.tokenOut || '').toUpperCase();
    const amountIn = Number(body.amountIn);
    if (!SWAP_TOKENS.includes(tokenIn) || !SWAP_TOKENS.includes(tokenOut)) {
      return { error: 'Unsupported token. Supported: USDC, EURC.' };
    }
    if (tokenIn === tokenOut) return { error: 'Choose two different tokens.' };
    if (!Number.isFinite(amountIn) || amountIn <= 0) return { error: 'Enter a valid amount.' };
    return { tokenIn, tokenOut, amountIn };
  }

  async function buildParams(userId, v) {
    const walletId = await getWalletId(userId);
    if (!walletId) throw new Error('No wallet for user');
    const info = await getWalletInfo(walletId);
    const { adapter } = await getKit();
    return {
      from: { adapter, chain: 'Arc_Testnet', address: info.address },
      tokenIn: v.tokenIn,
      tokenOut: v.tokenOut,
      amountIn: v.amountIn.toString(),
      allowanceStrategy: 'approve', // required for Circle SCA wallets
      config: { kitKey: KIT_KEY },
    };
  }

  // ── Estimate (quote) ──────────────────────────────────────────────────────
  app.post('/api/swap/estimate', authenticateUser, requireVerifiedUser, strictLimiter, async (req, res) => {
    try {
      if (!SWAP_ENABLED) return res.status(503).json({ error: 'Swap is not configured (missing KIT_KEY).' });
      const v = validate(req.body);
      if (v.error) return res.status(400).json({ error: v.error });
      const { kit } = await getKit();
      const params = await buildParams(req.body.userId, v);
      const estimate = await kit.estimateSwap(params);
      res.json({ ok: true, estimate });
    } catch (e) {
      console.error('[swap] estimate error:', e.message);
      res.status(502).json({ error: friendly(e.message) });
    }
  });

  // ── Execute swap ────────────────────────────────────────────────────────────
  app.post('/api/swap', authenticateUser, requireVerifiedUser, strictLimiter, async (req, res) => {
    try {
      if (!SWAP_ENABLED) return res.status(503).json({ error: 'Swap is not configured (missing KIT_KEY).' });
      const v = validate(req.body);
      if (v.error) return res.status(400).json({ error: v.error });
      // Preflight: USDC swaps must have the input balance in the Puls wallet.
      if (v.tokenIn === 'USDC') {
        try {
          const walletId = await getWalletId(req.body.userId);
          const info = walletId ? await getWalletInfo(walletId) : null;
          const bal = parseFloat(info?.usdcBalance ?? '0');
          if (bal < v.amountIn) {
            return res.status(402).json({ error: `Not enough USDC in your Puls wallet (have ${bal.toFixed(2)}). Deposit or bridge USDC first.` });
          }
        } catch (_) {}
      }
      const { kit } = await getKit();
      const params = await buildParams(req.body.userId, v);
      const result = await kit.swap(params);
      console.log(`[swap] ${v.amountIn} ${v.tokenIn} -> ${v.tokenOut} for ${req.body.userId} (tx ${result?.txHash})`);
      res.json({
        ok: true,
        tokenIn: v.tokenIn,
        tokenOut: v.tokenOut,
        amountIn: result?.amountIn ?? v.amountIn.toString(),
        amountOut: result?.amountOut ?? null,
        txHash: result?.txHash ?? null,
        explorerUrl: result?.explorerUrl ?? (result?.txHash ? `https://testnet.arcscan.app/tx/${result.txHash}` : null),
      });
    } catch (e) {
      console.error('[swap] execute error:', e.message);
      res.status(502).json({ error: friendly(e.message) });
    }
  });

  console.log(`[swap] routes registered (enabled: ${SWAP_ENABLED}${SWAP_ENABLED ? '' : ' — set KIT_KEY'})`);
}

// Turn raw SDK/pool errors into a user-readable message.
function friendly(msg) {
  const m = String(msg || '');
  // Balance first — most common and distinct from liquidity.
  if (/insufficient (token )?balance|insufficient funds/i.test(m)) {
    return 'Not enough USDC in your Puls wallet on Arc for this swap. Deposit or bridge USDC first, then try a smaller amount.';
  }
  if (/liquidity|imbalan|insufficient output|slippage/i.test(m)) {
    return 'Swap pool is thin on Arc testnet right now — try a smaller amount or again shortly.';
  }
  if (/revert|simulation failed/i.test(m)) {
    return 'The swap simulation reverted — usually thin Arc testnet liquidity or too large an amount. Try a smaller amount (e.g. 0.5) or again shortly.';
  }
  return m.slice(0, 200) || 'Swap failed.';
}
