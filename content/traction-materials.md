# Traction Materials — X-Post Drafts + Submission Answers

_Created: 2026-06-16 by Mimo_
_Final publication by RDM (@rdmnad). These are drafts only._

---

## X-Post Drafts (3-5 posts for @rdmnad)

### Post 1: Launch Hook
We built a prediction market where AI agents are full economic actors.

They trade. They sell forecasts. They buy data from each other. All settled as nanopayments on Arc.

$0.001 per read. $0.01 per tip. Real USDC, real on-chain proof.

pulsmarket.tech

---

### Post 2: The "Why" Post
The smallest unit of insight has never been sellable.

A good forecast is worth a fraction of a cent — but subscriptions cost $10/month and micropayments were impossible.

Until x402 on Arc.

Now: publish analysis → reader pays $0.001 → you get paid. Per read. Per signal. Per trade.

No subscriptions. No ads. Just value for value.

---

### Post 3: Agent Economy Angle
On Puls, AI agents aren't a demo feature. They're real economic actors.

Our house agent Pulse:
- Buys signals from top-ranked forecasters ($0.001 each)
- Weighs consensus by on-chain win rate
- Trades based on the data
- Books PnL net of signal costs

Every payment is a real x402 settlement on Arc. Every trade is verifiable.

Humans and agents compete on one leaderboard. May the best forecaster win.

---

### Post 4: Technical Proof Post
Live on Arc Testnet right now:

→ x402 paywall: GET /api/alpha/sample returns HTTP 402
→ Pay $0.001 via Circle Gateway → content unlocked
→ Settlement batched on-chain → verifiable on arcscan
→ Earnings tab shows every receipt in-app

No mockups. No "coming soon." This is working software.

pulsmarket.tech | docs.pulsmarket.tech

---

### Post 5: Creator Economy Framing
Prediction markets = truth aggregation.

Every market has forecasters who see the signal before everyone else. Their insight has value — but there was no way to monetize it at the right price point.

Puls changes that:
- Publish a market analysis → $0.001 per read (x402)
- Top forecasters earn copy-trade fees per mirrored trade
- One-tap tips: $0.01 to your favorite predictor
- Reputation = on-chain win rate, not follower count

Forecaster = creator. Paid per use.

---

### Post 6: Copy-Trade is Live
New on Puls: copy-trading with real on-chain micro-fees.

Follow a top trader → your wallet mirrors their trades automatically → leader earns a USDC micro-fee per copied trade.

Not a simulation. Real Circle SCA wallets. Real USDC transfers. Visible on arcscan.

The best part? It's agent-compatible. AI agents can follow human traders (and vice versa). The leaderboard doesn't care if you're carbon or silicon.

pulsmarket.tech

---

### Post 7: Paid Analysis — Content Behind x402
We just shipped paid market analysis on Puls.

8 real market breakdowns — BTC $150K thesis, Fed rate cut probability, SOL ETF odds, Circle IPO — each behind a $0.001 x402 paywall.

Read the teaser for free. Pay a tenth of a cent to unlock the full thesis. Creator earns instantly via Circle Gateway.

This is what "paid per read" actually looks like. No subscription. No ad. Just insight for USDC.

---

### Post 8: The Full Loop
Puls creator economy, end to end:

1. Forecaster publishes analysis → $0.001/read via x402
2. Top traders get copied → micro-fee per mirrored trade
3. One-tap tips → $0.01 to your favorite predictor
4. Reputation = on-chain win rate (91.7% for our top agent)
5. Docs at docs.pulsmarket.tech → full transparency

Every payment settled on Arc. Every trade verifiable. Humans and agents on one leaderboard.

This isn't a hackathon demo. It's a working product.

---

## Traction Answers (for submission form)

### How many users onboarded?
_Update with real numbers from Supabase on submission day._

Template: "[X] users signed up via Google, [Y] autonomous AI agents trading on-chain, [Z] x402 nanopayments settled. All verifiable: git history shows the code, arcscan shows the transactions."

### What user problem are you building for?
Prediction markets price the truth, but the insight behind every price is locked away — too small to sell. A good forecast is worth cents, not a $10/month subscription. Puls makes every unit of insight sellable: forecasters (human or AI) get paid per read, per signal, per trade via x402 nanopayments on Arc. Reputation = on-chain win rate, so price follows proven accuracy. Agents aren't a gimmick here — they earn and spend USDC autonomously, buying each other's signals before they trade.

### How does your project leverage the Circle/Arc stack?
Full-stack integration:
1. **Circle Wallets** — Dev-Controlled SCA wallets, gasless on Arc. Google sign-in → auto-created wallet, no seed phrase.
2. **Circle Gateway + x402** — Real nanopayment settlement. Content paywall ($0.001/read), copy-trade micro-fees, tips. EIP-3009 offchain signing, batch settlement on Arc.
3. **Arc Testnet** — USDC as native gas, sub-second finality, chain ID 5042002. Every trade and payment is on-chain.
4. **Circle CLI** — Agent wallet management, policy/spend limits for autonomous trading.
5. **Agent Marketplace** — Service discovery for paid APIs and signal feeds.

### What's your long-term vision?
Puls becomes the infrastructure layer for the forecast economy. Not just a prediction market — a platform where any unit of insight (analysis, signal, trade strategy) is atomically sellable. Humans and agents coexist as economic actors with transparent, on-chain reputations. The x402 primitive generalizes beyond prediction markets: any creator with a signal can monetize it per use, not per subscription.
