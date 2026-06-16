# QA Report — Puls (pulsmarket.tech)

_QA performed: 2026-06-16 by Mimo_

## Backend Health

| Endpoint | Status | Notes |
|---|---|---|
| `/health/deep` | ✅ OK | RPC 138ms, Supabase 431ms, Circle 355ms, Treasury 1144.80 USDC |
| `/api/x402/info` | ✅ OK | Configured=true, seller 0xa93F…894e, Gateway wallet 0x0077…19B9 |
| `/api/alpha/sample` | ✅ 402 | Paywall correctly returns HTTP 402 with payment requirements |
| `/api/x402/payments` | ✅ OK | 2 settled payments ($0.001 each), receiptIds present |
| `/api/copy/status` | ✅ 401 | Auth required — registered and working |
| `/api/markets` | ✅ OK | Returns live Polymarket data (Trump mentions, tennis, FIFA, weather) |
| `/api/leaderboard` | ✅ OK | Returns user data |

## Docs Site (docs.pulsmarket.tech)

| Check | Status | Notes |
|---|---|---|
| Landing page | ✅ OK | "What is Puls" renders correctly |
| CardGroup links | ✅ OK | Quickstart, How it works, Creator economy, Agents links present |
| Content quality | ✅ OK | Clear value prop, well-structured |
| Testnet disclaimer | ✅ OK | Present at bottom |

## Bugs Found

### BUG-1: Leaderboard — all non-top users show 0% win rate
- **Severity:** Medium
- **Steps:** `GET /api/leaderboard?limit=5`
- **Expected:** Users with 97-103 trades should have non-zero win rate
- **Actual:** All users except Dr RDM show `winRate: 0`, `pnl: 0` despite 97-103 trades
- **Hypothesis:** Win rate calculation only triggers after market resolution (3+ resolved markets). If markets haven't resolved yet, all PnL stays at 0. OR the mark-to-market PnL calculation has a bug for users who haven't closed positions.
- **⤴️ FOR VIKTOR:** Check `winRate` calculation logic in server.js leaderboard endpoint.

### BUG-2: Leaderboard — duplicate display names
- **Severity:** Low (cosmetic)
- **Steps:** `GET /api/leaderboard?limit=5`
- **Expected:** Unique display names or wallet-derived names
- **Actual:** 4 out of 5 users are named "Puls Trader" — indistinguishable
- **Suggestion:** Show truncated wallet address (e.g., "0x36e0…E36") when no custom display name is set
- **⤴️ FOR VIKTOR:** Fallback display name logic in leaderboard query

### BUG-3: Resolved sports markets still accepting orders
- **Severity:** Medium
- **Steps:** Check market `2554631` (Hontama vs Kulikova tennis)
- **Expected:** `acceptingOrders: false`, `closed: true` after match ended
- **Actual:** `ended: true`, `finishedTimestamp` set, but `acceptingOrders: true`, `closed: false`
- **Impact:** Users can place trades on already-resolved markets
- **⤴️ FOR VIKTOR:** Market archival/close logic should check `ended` flag from Polymarket and set `acceptingOrders: false`

### BUG-4: Landing page — minimal content in text fetch
- **Severity:** Low
- **Steps:** `GET https://pulsmarket.tech` via text fetch
- **Expected:** Full landing page content
- **Actual:** Only title "Puls — The Market for What Happens Next" and tagline visible
- **Note:** This may be a Flutter web rendering issue — the app renders via canvas, not HTML. Full content likely visible in browser. Not a real bug, but worth noting for SEO (crawlers see minimal content).

## Observations (not bugs)

1. **Markets API is fast** — returns live Polymarket data with rich metadata (event context, resolution sources, UMA bonds)
2. **x402 paywall works end-to-end** — 402 response includes correct Arc Testnet requirements (amount 1000 = $0.001, Gateway Wallet contract)
3. **Treasury healthy** — 1144.80 USDC, well above minimum (10)
4. **Copy-trade endpoint registered** — returns 401 (auth required), confirming PR #16 deploy succeeded
5. **Docs site is polished** — Mintlify rendering good, clear structure, proper disclaimers

## Summary

- **Backend:** Fully functional, all endpoints responding correctly
- **x402 flow:** Working end-to-end (402 → payment → settle)
- **Critical bugs:** 0
- **Medium bugs:** 2 (leaderboard win rates, resolved markets accepting orders)
- **Low bugs:** 2 (duplicate names, landing SEO)
- **Overall:** Product is in good shape for hackathon demo. The leaderboard win rate issue is the most visible to judges — fixing it would improve the "humans vs agents" narrative.
