# Canteen / Lepton update — 2026-07-04

_Fresh from `/api/stats` + `/api/streams/stats/summary` at 2026-07-04._

## Live traction (Arc testnet — all on-chain, verifiable on Arcscan)
| Metric | Value | Since 06-29 |
|---|---|---|
| x402 nanopayments settled | **4,638** ($62.55 vol · smallest $0.001) | ▲ from 2,349 (**+97% count, 8x volume!**) |
| Pay-per-second Streams | **409** ($53.88 streamed) | *New metric (shipped 06-29)* |
| Autonomous agent trades | **3,298** across 12 agents | ▲ from 2,530 (**+30%**) |
| Agent USDC volume | **$1,391.85** (vs humans $420.93) | ▲ from $966 |
| Markets deployed / resolved | **1,062 / 720** | ▲ from 846 / 467 |
| Organic trades (humans + agents) | **3,500** ($1,812.77 volume) | ▲ from 2,712 |
| Trades on-chain (incl. seed) | 9,003 | ▲ from 8,215 |
| Wallets onboarded | 32 | ▲ from 30 |

> **Honest accounting:** seed/liquidity wallets (5,503 trades, ~$11) are tracked separately in `/api/stats` and **excluded** from the organic figures above.

**Headline:** Puls Streams is exploding on-chain volume. x402 nanopayments **nearly doubled again** in just 5 days (2,349 → 4,638), while the actual USDC volume flowing through these micropayments surged **8x** ($7.25 → $62.55) thanks to agents heavily utilizing the new pay-per-second streaming capability. Agents now account for **76% of all organic trading volume** on Puls ($1,391 vs human $420). 

---

## Update — what's new since 06-29

**We shipped a massive "Premium Polish" visual overhaul across the entire frontend.**

While the agent economy and on-chain contracts were already state-of-the-art, the web app was starting to fall behind the capabilities of the protocol. We spent the last 5 days completely unifying and elevating the aesthetic of the entire `Puls` web suite:

- **Flawless Bento Grids:** We migrated the entire UI to a rigorous, 1px-gap bento grid layout. We engineered tight CSS (`overflow:hidden`, `border-radius:16px` on parents, `0px` on children) to eliminate all visual bleeding, creating a seamless, glassy structural layout.
- **Unified Animated Mesh Canvas:** Replaced static dark backgrounds with a rich, fully-animated `.mesh` layer that drifts globally beneath the glass panels. Patched deep z-index and body background bugs to ensure this deep Web3 aesthetic is universally consistent across all 8 web pages (`cli.html`, `mobile-download.html`, `agent.html`, etc.).
- **Dynamic Micro-Interactions & Shimmers:** Replaced clunky emoji elements with crisp, tinted SVG line icons. Injected vivid, multi-colored hover glows (`mix-blend-mode: overlay`, `radial-gradient`) into every card. Finally, we added a gorgeous sweeping text shimmer effect to the hero titles (e.g., *"The prediction market in your terminal"*).

**Why it matters:** Puls is a highly technical product (autonomous agents trading and streaming micro-cents to each other on a high-speed rollup). By bringing the UI to a premium, "Apple-meets-Web3" standard, the developer and user experience now matches the underlying power of the protocol.

---

## Short traction tweet (X / Canteen feed)

> Approaching the end of the @canteen × @circle Lepton hackathon, the agent economy on Puls (Arc) is going parabolic:
> • 4,638 x402 nanopayments settled (+97% in 5 days) 
> • Nanopayment volume surged 8x ($7.25 → $62.55) driven by 409 new pay-per-second Streams
> • Agents continue to dominate: $1,391 in volume vs $420 by humans across 3,298 trades.
> We also just shipped a massive, glassy bento-grid UI overhaul to match the protocol's power.
> Every single payment and trade is verifiable on Arcscan → pulsmarket.tech

## One-liner (Canteen update field)

> **Traction surge + UI Overhaul:** Driven by the new Puls Streams (pay-per-second), x402 nanopayments nearly doubled (4,638) and micro-volume 8x'd ($62) in just 5 days. Agents now drive 76% of organic volume. We also completely rebuilt the web frontend into a seamless, animated bento-grid glassmorphism UI to match the protocol's state-of-the-art tech. 

## Even shorter (one-sentence traction)

> On Puls (Arc), AI agents now drive 76% of organic trading volume, while our new pay-per-second streaming feature pushed total on-chain x402 nanopayments to 4,638 (an 8x surge in micro-volume this week).
