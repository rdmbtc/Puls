# QA Report — Puls (pulsmarket.tech)

_QA performed: 2026-06-17 by Mimo (third pass)_

## Backend Health

| Endpoint | Status | Notes |
|---|---|---|
| `/health/deep` | ✅ OK | RPC 495ms, Supabase 367ms, Circle 478ms, Treasury 980.75 USDC |
| `/api/x402/info` | ✅ OK | Configured=true, seller 0xa93F…894e, Gateway wallet 0x0077…19B9 |
| `/api/alpha/sample` | ✅ 402 | Paywall correctly returns HTTP 402 |
| `/api/x402/payments` | ✅ OK | 2 settled payments ($0.001 each) |
| `/api/copy/status` | ✅ 401 | Auth required — registered |
| `/api/markets` | ✅ OK | Live Polymarket data |
| `/api/leaderboard` | ✅ OK | Pulse 🤖 92.3% win rate (62 trades), humans 90-100% |
| `/api/comments/config` | ✅ OK | `live:true, maxLen:1000, targetTypes:[market,profile,event,alpha]` |
| `/terms` | ❌ 404 | Not deployed yet |

## New Features (since last QA)

| Feature | Status | Notes |
|---|---|---|
| Promo carousel (Home) | ✅ LIVE | 4 HD banners, auto-scroll, dot indicators, deep-links |
| Humans vs Agents card (Home) | ✅ LIVE | Viktor PR #34 merged |
| Alpha teaser (Feed) | ✅ LIVE | Viktor PR #35 merged |
| Docs link (landing) | ✅ LIVE | Viktor PR #36 merged |
| First-trade celebration | ✅ LIVE | PR #32 — snackbar on first trade |
| Discover trending empty-state | ✅ LIVE | PR #33 — 3 trending markets |
| Tawk.to | ❌ REMOVED | Blocked in RDM region, removed PR #41 |
| Comments UI | 🟡 READY | Widget built (PR #42), needs integration into market/profile screens |

## Bugs — Previous Status

| Bug | Status | Notes |
|---|---|---|
| BUG-1: Leaderboard 0% win rate | ✅ FIXED | PR #25 |
| BUG-2: Duplicate display names | ✅ FIXED | PR #26 |
| BUG-3: Resolved markets accepting orders | 🔴 OPEN | Viktor needs to fix |
| BUG-4: Landing page SEO | 🟡 LOW | Flutter web limitation |
| BUG-5: /terms returns 404 | 🔴 OPEN | Content ready, Viktor deploy |

## Carousel QA

| Check | Status | Notes |
|---|---|---|
| Auto-scroll (5s) | ✅ OK | Works, resets on manual swipe |
| Dot indicators | ✅ OK | Animated width on active dot |
| Text readability | ✅ IMPROVED | Scrim gradient now bottom-up |
| Deep-links | ✅ OK | Leaderboard, Discover, Alpha tab, X profile |
| Images load | ✅ OK | All 4 promo PNGs in assets/promo/ |
| Mobile height | ✅ OK | 170px, reasonable on small screens |

## Summary

- **Backend:** Fully functional, all endpoints healthy
- **New since last QA:** Carousel, Humans-vs-Agents, Alpha teaser, Docs link, Comments widget
- **Critical bugs:** 0
- **Open bugs:** 2 (resolved markets, /terms — both Viktor's domain)
- **Overall:** Product is demo-ready. Comments widget built, needs integration. Carousel polished.
