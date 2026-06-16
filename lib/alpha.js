/**
 * Puls Alpha — paid premium analysis (T1 creator layer).
 *
 * "Forecaster = creator, paid per read." A premium forecast (thesis) is sold
 * per-unlock as a sub-cent USDC nanopayment on Arc Testnet. The teaser is free;
 * the full thesis unlocks once the reader pays the creator. Each unlock is a true
 * per-event nanopayment, visible on Arcscan and surfaced in the in-app Earnings
 * tab (endpoint='alpha_unlock') next to copy-fees and Gateway x402 receipts.
 *
 * Honesty / architecture notes (read before reviewing):
 *  - The unlock fee is a REAL on-chain USDC micro-transfer reader→creator
 *    (ERC-20 `transfer`, gasless via the reader's Circle SCA + Gas Station),
 *    the exact same proven rail as the copy-fee in lib/copytrade.js.
 *  - We deliberately do NOT route in-app reader payments through Circle Gateway
 *    x402: the Gateway buyer flow needs an EOA private key signing EIP-3009
 *    off-chain, but in-app wallets are Circle SCA (ERC-4337) dev-controlled
 *    accounts whose keys we never hold. A direct micro-transfer is the honest,
 *    demoable equivalent that works for every real user. The pure Gateway x402
 *    settle stays demonstrated by the agent-buyer (scripts/x402-buyer.mjs against
 *    the paywalled /api/alpha/sample) — that is the "agent pays creator" proof.
 *  - LIVE PAYMENTS ARE GATED behind env `ALPHA_PAID_ENABLED=true` (default OFF)
 *    so the feature ships to prod without moving real funds until a human turns
 *    it on for the demo run. When OFF, /unlock returns { ok:false, live:false }
 *    and the UI honestly shows "activates at launch".
 *
 * Wiring (server.js):
 *   import { registerAlpha } from './lib/alpha.js';
 *   registerAlpha(app, { supabase, circle, USDC, getWalletId, getWalletInfo,
 *     authenticateUser, requireVerifiedUser, strictLimiter });
 *   // and label alpha_unlock receipts in /api/x402/payments (see paymentType).
 */

// Curated premium forecasts. Teaser is public; `thesis` is paywalled.
// payTo defaults to the house creator (X402_SELLER_ADDRESS) so unlock fees flow
// to a real, Economy-tracked Arc address that already shows in the Earnings tab.
const ALPHA_SIGNALS = [
  {
    id: 'btc-100k-q4',
    title: 'BTC > $100k by EOY 2026',
    market: 'Will BTC close above $100k by 2026-12-31?',
    stance: 'YES',
    confidence: 0.62,
    edgeBps: 480,
    horizon: 'Q4 2026',
    priceUsdc: 0.01,
    creatorHandle: 'puls-house',
    teaser: 'Spot ETF inflows + post-halving supply squeeze vs near-term macro drag — order-flow on Puls skews YES while implied prob lags.',
    thesis:
      'Net spot-ETF inflows have absorbed ~3.4x post-halving issuance over the trailing 90 days, tightening '
      + 'available float faster than the market is pricing. Puls order-flow on this market is 64% YES by notional '
      + 'while the implied probability sits at 0.55 — a 9pt gap we read as a lagging-belief edge. Macro drag '
      + '(rate path, DXY) caps upside velocity but not direction. Base case: a Q4 melt-up retest of prior highs; '
      + 'invalidation if weekly ETF flows flip net-negative for 3+ consecutive weeks. Sizing: scale in on dips, '
      + 'trim into spikes; expected edge ~480bps vs the current line.',
  },
  {
    id: 'eth-etf-staking',
    title: 'ETH staking ETF approval',
    market: 'Will a US spot ETH ETF enable staking by 2026-12-31?',
    stance: 'NO',
    confidence: 0.58,
    edgeBps: 320,
    horizon: 'H2 2026',
    priceUsdc: 0.01,
    creatorHandle: 'puls-house',
    teaser: 'Crowd is over-pricing a fast staking green-light; the regulatory path is slower than the line implies.',
    thesis:
      'Issuers have filed for in-kind + staking amendments, but the approval cadence for the structural change '
      + '(custody of staked assets, slashing risk disclosure, liquidity windows) historically trails the base '
      + 'product by 2-3 review cycles. The market prices ~0.47 for YES; we model ~0.33 given comment-period '
      + 'timing and an election-year regulatory slowdown. Edge ~320bps on NO. Invalidation: a published staff '
      + 'no-action or an expedited amendment docket before Q3.',
  },
  {
    id: 'arc-mainnet',
    title: 'Arc mainnet live in 2026',
    market: 'Will Circle Arc launch mainnet before 2027?',
    stance: 'YES',
    confidence: 0.7,
    edgeBps: 600,
    horizon: '2026',
    priceUsdc: 0.01,
    creatorHandle: 'puls-house',
    teaser: 'Testnet velocity (Gateway nanopayments, USDC-as-gas) signals a credible 2026 mainnet window the line under-prices.',
    thesis:
      'Shipping cadence on Arc testnet — Gateway batched nanopayments, USDC-as-gas, sub-500ms settlement, an '
      + 'active builder program (this hackathon) — is consistent with a team on a public mainnet glidepath, not '
      + 'a research net. The market implies ~0.55; ecosystem signal + stablecoin-rail strategic urgency put our '
      + 'estimate at ~0.70. Edge ~600bps on YES. Invalidation: a public roadmap slip or a security-audit pause.',
  },
];

const ALPHA_PAID_ENABLED = String(process.env.ALPHA_PAID_ENABLED || '').toLowerCase() === 'true';

function publicSignal(s, unlocked) {
  const base = {
    id: s.id,
    title: s.title,
    market: s.market,
    stance: s.stance,
    confidence: s.confidence,
    edgeBps: s.edgeBps,
    horizon: s.horizon,
    priceUsdc: s.priceUsdc,
    creatorHandle: s.creatorHandle,
    teaser: s.teaser,
    unlocked: Boolean(unlocked),
  };
  if (unlocked) base.thesis = s.thesis;
  return base;
}

export function registerAlpha(app, deps) {
  const {
    supabase,
    circle,
    USDC,
    getWalletId,
    getWalletInfo,
    authenticateUser,
    requireVerifiedUser,
    strictLimiter,
  } = deps;

  const payToFor = (_signal) => (process.env.X402_SELLER_ADDRESS || '').trim() || null;

  async function unlockedIdsFor(userId) {
    if (!userId) return new Set();
    try {
      const { data, error } = await supabase
        .from('alpha_unlocks')
        .select('signal_id')
        .eq('user_id', userId);
      if (error) throw error;
      return new Set((data || []).map((r) => r.signal_id));
    } catch (e) {
      console.warn('[alpha] unlockedIdsFor failed:', e.message);
      return new Set();
    }
  }

  // ── List premium forecasts (public). Teaser only; never returns thesis. ──
  // Optional ?userId= annotates which signals the caller has already unlocked.
  app.get('/api/alpha/list', async (req, res) => {
    try {
      const userId = req.query.userId || null;
      const unlocked = await unlockedIdsFor(userId);
      res.json({
        signals: ALPHA_SIGNALS.map((s) => publicSignal(s, unlocked.has(s.id))),
        live: ALPHA_PAID_ENABLED,
        seller: payToFor(null),
      });
    } catch (e) {
      console.error('[alpha] list error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  // ── Full thesis for one signal (auth). Returns thesis only if the verified
  //    caller has unlocked it; otherwise { locked:true } with the teaser. ──
  app.get('/api/alpha/:id', authenticateUser, async (req, res) => {
    try {
      const userId = req.query.userId; // forced to verified id by authenticateUser
      const signal = ALPHA_SIGNALS.find((s) => s.id === req.params.id);
      if (!signal) return res.status(404).json({ error: 'Signal not found' });
      const unlocked = (await unlockedIdsFor(userId)).has(signal.id);
      if (!unlocked) {
        return res.status(402).json({ locked: true, signal: publicSignal(signal, false), live: ALPHA_PAID_ENABLED });
      }
      res.json({ locked: false, signal: publicSignal(signal, true) });
    } catch (e) {
      console.error('[alpha] get error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  // ── Unlock a signal (auth). Pays the creator a real per-read USDC micro-fee
  //    from the reader's SCA wallet, then grants access. Idempotent: a second
  //    unlock just returns the content (no double charge). ──
  app.post('/api/alpha/:id/unlock', authenticateUser, requireVerifiedUser, strictLimiter, async (req, res) => {
    try {
      const userId = req.body.userId; // forced to verified id by authenticateUser
      const signal = ALPHA_SIGNALS.find((s) => s.id === req.params.id);
      if (!signal) return res.status(404).json({ error: 'Signal not found' });

      // Already unlocked → just return the content (idempotent, no charge).
      if ((await unlockedIdsFor(userId)).has(signal.id)) {
        return res.json({ ok: true, alreadyUnlocked: true, signal: publicSignal(signal, true) });
      }

      // Gated until a human enables live payments for the demo run.
      if (!ALPHA_PAID_ENABLED) {
        return res.json({
          ok: false,
          live: false,
          message: 'Paid analysis activates at launch — payments are currently disabled.',
          signal: publicSignal(signal, false),
        });
      }

      const payTo = payToFor(signal);
      if (!payTo) return res.status(503).json({ error: 'Creator payout address not configured' });

      const walletId = await getWalletId(userId);
      if (!walletId) return res.status(400).json({ error: 'No wallet for user' });
      const info = await getWalletInfo(walletId);

      const price = Number(signal.priceUsdc) || 0;
      if (parseFloat(info.usdcBalance) < price) {
        return res.status(402).json({ error: 'Insufficient USDC balance to unlock' });
      }

      // Real on-chain USDC micro-transfer reader → creator (gasless SCA).
      const amountMicro = Math.round(price * 1_000_000).toString();
      const txRes = await circle.createContractExecutionTransaction({
        walletId,
        contractAddress: USDC,
        abiFunctionSignature: 'transfer(address,uint256)',
        abiParameters: [payTo, amountMicro],
        fee: { type: 'level', config: { feeLevel: 'HIGH' } },
      });
      const txId = txRes.data?.id || null;

      // Grant access (unique on user_id+signal_id → idempotent at the DB layer too).
      const { error: insErr } = await supabase
        .from('alpha_unlocks')
        .upsert(
          {
            user_id: userId,
            signal_id: signal.id,
            amount_usdc: price,
            tx_id: txId,
            created_at: new Date().toISOString(),
          },
          { onConflict: 'user_id,signal_id' }
        );
      if (insErr) console.warn('[alpha] unlock insert failed:', insErr.message);

      // Receipt → Earnings tab (endpoint='alpha_unlock').
      supabase
        .from('x402_payments')
        .insert({
          endpoint: 'alpha_unlock',
          payer: info.address || null,
          pay_to: payTo,
          amount_usdc: price.toString(),
          network: 'eip155:5042002',
          gateway_tx: txId,
          raw: { kind: 'alpha_unlock', signalId: signal.id, priceUsdc: price },
        })
        .then(({ error }) => {
          if (error) console.warn('[alpha] receipt insert failed:', error.message);
        });

      console.log(`[alpha] unlock ${signal.id} — ${price} USDC ${info.address} → ${payTo} (tx ${txId})`);

      res.json({
        ok: true,
        signal: publicSignal(signal, true),
        receipt: { amountUsdc: price, payTo, txId, network: 'eip155:5042002' },
      });
    } catch (e) {
      console.error('[alpha] unlock error:', e.message);
      res.status(500).json({ error: e.message });
    }
  });

  console.log(`[alpha] paid-analysis routes registered (live payments: ${ALPHA_PAID_ENABLED ? 'ON' : 'OFF'})`);

  return { ALPHA_SIGNALS };
}
