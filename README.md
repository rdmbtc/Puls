# Puls

**Mobile-first prediction market built on [Arc](https://arc.network) — Circle's stablecoin-native L1 where USDC is the gas token.**

Users sign in with Google → get a Circle MPC wallet instantly → swipe to trade real predictions with USDC as gas. No ETH, no seed phrase, no friction. Sub-second finality.

---

> 🏆 **Hackathon submission (Stablecoin Commerce Stack Challenge — Track 4: Best Agentic Economy Experience on Arc):** see [SUBMISSION.md](SUBMISSION.md) — architecture diagram, Circle integration docs, Circle Product Feedback, and demo script.

## ⏱ The 2-Minute Demo

1. **Open [pulsmarket.tech](https://pulsmarket.tech)** — note the live market tape: those are real markets with real prices
2. **Sign in with Google** — a Circle MPC wallet is created instantly: no seed phrase, no extension, no ETH
3. **Swipe right** on a market — a real LMSR trade on Arc Testnet, gas paid in USDC, confirmed in under a second (watch the timer in the confirmation sheet)
4. **Open the market detail** — live price chart, order book, and the "How this market resolves" panel showing the UMA oracle status and dispute window
5. **Tap "View on Arcscan"** — every trade, market, and oracle interaction is verifiable on-chain

---

## Why Arc?

Arc is the only chain where USDC is the **native gas token**. This unlocks a UX that isn't possible anywhere else:

| Arc Advantage | What It Means for Puls |
|---|---|
| **USDC as gas** | Users never need ETH — one token for everything |
| **Sub-second finality** | Trades confirm in < 1 second, feels instant |
| **Predictable fees** | Gas costs are stable (no volatile ETH pricing) |
| **Circle full-stack** | MPC wallets + USDC + compliance in one ecosystem |

---

## Features

### Core Trading
- **Google sign-in** → Circle MPC wallet created automatically (no seed phrase)
- **Swipe trading** — swipe right for YES, left for NO with haptic feedback and visual overlays
- **Sell positions** — sell back shares at current LMSR price, USDC returned to wallet
- **Claim winnings** — claim payout from resolved markets directly to wallet
- **Limit orders** — set target prices with automatic execution engine
- **Real USDC trades** — all transactions on Arc Testnet smart contracts

### Market Intelligence
- **100+ live markets** — real-time odds from Polymarket, deployed on-demand to Arc
- **Market detail view** — price charts, order book depth, market info
- **Category filtering** — Politics, Crypto, Sports, Tech, Entertainment, and more
- **Custom market creation** — create your own prediction markets on-chain

### Social & Gamification
- **Live betting feed** — real-time trade stream via WebSocket (HTTP polling fallback)
- **Leaderboard** — ranked traders by profit, win rate, volume, and trade count
- **Trader profiles** — per-user statistics with trade history
- **Push notifications** — trade confirmations and market alerts

### AI-Powered
- **Autonomous trading agent** — deposit USDC and let the AI trade with natural language instructions
- **Strategy presets** — Arbitrage mode (cross-market price gaps) and DCA mode (scheduled buys)
- **AI copilot** — ask questions about markets, get AI-powered analysis
- **Budget-capped** — agent enforces per-trade and total budget limits

### UX Polish
- **TikTok-style home** — vertical video feed with prediction overlays
- **Dynamic Island nav** — floating navigation bar with smooth transitions
- **Dark/light theme** — premium design with glassmorphism effects
- **Sub-second confirmation** — fast-poll transaction status with Arc speed showcase
- **Web landing page** — responsive marketing site with live stats

---

## Stack

| Layer | Tech |
|---|---|
| Mobile | Flutter (Android + Web) |
| Auth | Supabase + Google OAuth |
| Wallets | Circle Developer-Controlled Wallets (MPC) |
| Blockchain | Arc Testnet (Chain ID `5042002`) |
| Gas token | USDC — no ETH needed |
| Market data | Polymarket Gamma API |
| Backend | Node.js + Express + WebSocket (`ws`) |
| Smart contracts | Solidity 0.8.24 (Foundry) |
| Database | Supabase (PostgreSQL) |
| AI | LLM-powered agent + copilot |
| Deployment | VPS + PM2 |

---

## Smart Contracts

### LMSRMarketFactory

Factory contract that deploys individual prediction markets on-demand using the Logarithmic Market Scoring Rule (LMSR) for automated market making.

- **Address**: [`0x92c2fd35c0f1a501993be8e0fdae7caa34a8b80b`](https://testnet.arcscan.app/address/0x92c2fd35c0f1a501993be8e0fdae7caa34a8b80b)
- **Source**: `contracts/src/LMSRMarketFactory.sol`

### PulsMarket (per-question)

Each prediction deploys its own `PulsMarket` contract via the factory. Supports:
- `buyYes()` / `buyNo()` — purchase outcome shares with USDC
- `sellYes()` / `sellNo()` — sell shares back at LMSR price
- `claimWinnings()` — withdraw payout after resolution
- `resolve(bool)` — oracle-triggered outcome settlement

---

## Oracle & Auto-Resolution — UMA Optimistic Oracle V2 on Arc

UMA's oracle stack isn't deployed on Arc Testnet — so **we deployed it ourselves** and built a trust-minimized resolution pipeline on top:

| Contract | Address |
|---|---|
| OptimisticOracleV2 | [`0x363dF46534b9b7764C49504aDE0F7c8DD3c82Cae`](https://testnet.arcscan.app/address/0x363dF46534b9b7764C49504aDE0F7c8DD3c82Cae) |
| UMAResolverAdapter | [`0x013675668842505839fdc581f56746593fDAB85D`](https://testnet.arcscan.app/address/0x013675668842505839fdc581f56746593fDAB85D) |
| Finder | [`0x413ffcC8B552Ca2247442D05dDDb7B23994AC9D2`](https://testnet.arcscan.app/address/0x413ffcC8B552Ca2247442D05dDDb7B23994AC9D2) |
| Store | [`0x0d7957929B464d6ff5fc8D01769aD450B92c5F3E`](https://testnet.arcscan.app/address/0x0d7957929B464d6ff5fc8D01769aD450B92c5F3E) |

**How a market resolves:**

1. **Background cron** (every 5 min) scans deployed markets past their deadline
2. Anyone (permissionlessly) calls `requestResolution()` on the `UMAResolverAdapter` — this opens a `YES_OR_NO_QUERY` price request on UMA's OptimisticOracleV2, bonded in USDC
3. The backend **proposer bot** fetches the Polymarket consensus outcome and proposes it to the oracle, posting a 1 USDC bond
4. A **dispute window (liveness)** opens — anyone who disagrees can dispute and escalate
5. After liveness passes undisputed, anyone calls `settleAndResolve()` — the oracle's answer is pushed on-chain into `LMSRMarket.resolve(outcome)`
6. Users call `claimWinnings()` to collect their payout

Direct admin resolution remains available as a fallback behind the `UMA_RESOLUTION` env flag, but the oracle path means **no single party decides outcomes** — they're proposed, bonded, and disputable, exactly like Polymarket's own resolution on mainnet.

---

## Architecture

```
┌─────────────┐   Google OAuth   ┌──────────────┐
│  Flutter App │ ───────────────▷ │ Supabase Auth │
└──────┬──────┘                  └──────────────┘
       │ userId
       ▼
┌──────────────┐   Circle SDK    ┌───────────────────────┐
│ Node.js API  │ ───────────────▷│ Circle MPC Wallet     │
│ + WebSocket  │                 │ (Arc Testnet)         │
└──────┬───────┘                 │ • No seed phrase      │
       │                         │ • Instant on sign-up  │
       │ createMarket()          └──────────┬────────────┘
       ▼                                    │ USDC (gas token)
┌───────────────────┐    buyYes/buyNo()     │
│ LMSRMarketFactory │ ◁────────────────────-┘
│ 0x92c2…8b80b      │    sellYes/sellNo()
└───────┬───────────┘    claimWinnings()
        │ creates
        ▼
┌──────────────────┐     verified source     ┌──────────────────┐
│ PulsMarket.sol   │ ─────────────────────▷  │ Arcscan Explorer │
│ (per-question)   │                         │ Chain ID 5042002 │
└──────────────────┘                         └──────────────────┘

Key: USDC is the ONLY token. No ETH needed. Sub-second finality.
```

---

## Setup

### Prerequisites
- Flutter SDK (≥ 3.3.0)
- Node.js 20+
- Circle API key — [console.circle.com](https://console.circle.com)
- Supabase project — [supabase.com](https://supabase.com)
- Foundry (for contract deployment only)

### 1. Clone
```bash
git clone https://github.com/rdmbtc/puls.git
cd puls
```

### 2. Smart Contracts (optional — already deployed)
```bash
cd contracts
cp .env.example .env
# Fill in deployer private key and RPC URL
forge build
node deployFactory.mjs
```

### 3. Backend
```bash
cd backend
cp .env.example .env
# Fill in all required values (see below)

# Run Supabase schema (paste supabase-schema.sql in Supabase SQL Editor)

npm install
node server.js
```

**Required environment variables:**
| Variable | Description |
|---|---|
| `CIRCLE_API_KEY` | Circle Developer Console API key |
| `CIRCLE_APP_ID` | Circle application ID |
| `CIRCLE_ENTITY_SECRET` | 32-byte hex entity secret for MPC wallets |
| `FACTORY_ADDRESS` | Deployed LMSRMarketFactory contract address |
| `PRIVATE_KEY` | Admin wallet private key (for market deployment & resolution) |
| `WALLET_SET_ID` | Circle wallet set ID (created on first run) |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_KEY` | Supabase service role key |
| `ARC_RPC_URL` | Arc Testnet RPC endpoint |
| `AGENT_LLM_URL` | LLM API endpoint for AI agent/copilot |
| `AGENT_LLM_KEY` | LLM API key |
| `AGENT_MODEL` | LLM model name |

### 4. Flutter App
```bash
# Copy secrets template
cp lib/core/secrets.dart.example lib/core/secrets.dart
# Fill in your Supabase URL, anon key, and backend URL

flutter pub get
flutter run
```

### 5. Get Testnet USDC
[faucet.circle.com](https://faucet.circle.com) → Arc Testnet → paste your wallet address

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/wallet/get-or-create` | Create or retrieve MPC wallet |
| GET | `/api/wallet/balance` | Get USDC balance |
| GET | `/api/markets` | List markets with live odds |
| POST | `/api/market/activate` | Deploy market contract on-chain |
| GET | `/api/market/info` | Get on-chain market details |
| POST | `/api/trade/buy` | Buy YES/NO shares |
| POST | `/api/trade/sell` | Sell shares back |
| POST | `/api/trade/claim` | Claim winnings from resolved market |
| GET | `/api/trade/status` | Poll transaction status |
| GET | `/api/trade/recent` | Recent trades for live feed |
| POST | `/api/trade/limit-order` | Place a limit order |
| GET | `/api/portfolio` | User's portfolio positions |
| GET | `/api/leaderboard` | Ranked trader leaderboard |
| GET | `/api/profile/:userId` | Trader profile & statistics |
| POST | `/api/agent/start` | Start AI trading agent |
| POST | `/api/agent/chat` | Chat with AI agent |
| POST | `/api/copilot/chat` | AI copilot market analysis |
| POST | `/api/markets/create` | Create custom market |
| WebSocket | `/` | Real-time trade stream |

---

## Built on Arc

[arc.network](https://arc.network) · [Arc Blueprint: Prediction Markets](https://arc.network/blog/prediction-markets)

Puls is purpose-built for Arc because prediction markets need **instant confirmation** (sub-second finality), **stable costs** (USDC gas), and **zero onboarding friction** (Circle MPC wallets). This combination isn't possible on any other chain.
