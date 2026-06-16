# QA Report — Puls (pulsmarket.tech)

_QA performed: 2026-06-16 by Mimo (second pass)_

## Backend Health

| Endpoint | Status | Notes |
|---|---|---|
| `/health/deep` | ✅ OK | RPC 405ms, Supabase 365ms, Circle 446ms, Treasury 1060.79 USDC |
| `/api/x402/info` | ✅ OK | Configured=true, seller 0xa93F…894e, Gateway wallet 0x0077…19B9 |
| `/api/alpha/sample` | ✅ 402 | Paywall correctly returns HTTP 402 with payment requirements |
| `/api/x402/payments` | ✅ OK | 2 settled payments ($0.001 each), receiptIds present |
| `/api/copy/status` | ✅ 401 | Auth required — registered and working |
| `/api/markets` | ✅ OK | Returns live Polymarket data |
| `/api/leaderboard` | ✅ OK | Real data with win rates (Pulse 🤖 91.7%, humans 90-100%) |
| `/terms` | ❌ 404 | Not deployed yet — Viktor needs to integrate content/terms-of-use.md |

## Docs Site (docs.pulsmarket.tech)

| Check | Status | Notes |
|---|---|---|
| Landing page | ✅ OK | "What is Puls" renders correctly |
| CardGroup links | ✅ OK | Quickstart, How it works, Creator economy, Agents |
| Content quality | ✅ OK | Clear value prop, well-structured |
| Testnet disclaimer | ✅ OK | Present at bottom |

## UI Checks (after PRs #25, #26, #29)

| Check | Status | Notes |
|---|---|---|
| Win Rate display | ✅ FIXED | Shows "—" for 0% (PR #25 merged) |
| Display names | ✅ FIXED | Truncated wallet addresses instead of "Puls Trader" (PR #26 merged) |
| Notifications theme | ✅ FIXED | Theme inversion removed (PR #29 merged) |
| Documentation link | ✅ ADDED | Profile → docs.pulsmarket.tech (PR #29 merged) |
| Leaderboard data | ✅ OK | Pulse 🤖 91.7%, real humans showing 90-100% win rate |

## Bugs — Previous Status

| Bug | Status | Notes |
|---|---|---|
| BUG-1: Leaderboard 0% win rate | ✅ FIXED | PR #25 — now shows "—" for new users |
| BUG-2: Duplicate display names | ✅ FIXED | PR #26 — truncated wallet addresses |
| BUG-3: Resolved markets accepting orders | 🔴 OPEN | Viktor needs to fix market archival logic |
| BUG-4: Landing page SEO | 🟡 LOW | Flutter web limitation, not blocking |

## New Findings

### BUG-5: /terms returns 404
- **Severity:** Medium
- **Steps:** `GET https://84-22-148-57.sslip.io/terms`
- **Expected:** Terms of Use page
- **Actual:** 404 Not Found
- **Note:** Content ready in `content/terms-of-use.md` — Viktor needs to deploy
- **⤴️ FOR VIKTOR:** Integrate terms content into a route

### BUG-6: Alpha/tips/copy-trade behind feature flags
- **Severity:** Info (expected)
- **Note:** `COPY_TRADE_ENABLED` and `ALPHA_PAID_ENABLED` are OFF on prod. Features work but not visible to users.
- **Status:** Expected for pre-demo state. RDM will enable for demo recording.

## Summary

- **Backend:** Fully functional, all endpoints responding
- **x402 flow:** Working end-to-end (402 → payment → settle)
- **Critical bugs:** 0
- **Medium bugs:** 2 (resolved markets accepting orders, /terms 404)
- **Low bugs:** 1 (landing SEO — Flutter limitation)
- **Fixed since last QA:** 3 (win rate display, display names, notifications theme)
- **Overall:** Product is demo-ready. Main remaining items are Viktor's domain (terms page, market archival).
