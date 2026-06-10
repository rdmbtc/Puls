# Puls

**Mobile-first prediction market built on [Arc](https://arc.network) — Circle's stablecoin-native L1 where USDC is the gas token.**

Users sign in with Google → get a Circle MPC wallet instantly → swipe to trade real predictions with USDC as gas. No ETH, no seed phrase, no friction. Sub-second finality.

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

- **Address**: [`0xa478b966742f3e35f3fb4659318c8e6e7647cbb0`](https://testnet.arcscan.app/address/0xa478b966742f3e35f3fb4659318c8e6e7647cbb0)
- **Source**: `contracts/src/LMSRMarketFactory.sol`

### PulsMarket (per-question)

Each prediction deploys its own `PulsMarket` contract via the factory. Supports:
- `buyYes()` / `buyNo()` — purchase outcome shares with USDC
- `sellYes()` / `sellNo()` — sell shares back at LMSR price
- `claimWinnings()` — withdraw payout after resolution
- `resolve(bool)` — oracle-triggered outcome settlement

---

## Oracle & Auto-Resolution

Puls implements a fully automated oracle pipeline — no manual intervention needed:

1. **Background cron** runs every 5 minutes on the backend
2. Scans all deployed markets past their deadline
3. Queries **Polymarket Gamma API** for consensus outcome (`consensusOutcome` field)
4. If the source market is resolved, calls `resolve(bool)` on the Arc smart contract
5. Updates the database and broadcasts resolution via WebSocket

This means markets settle automatically once Polymarket reports an outcome. The on-chain `resolve()` call is permissioned to the admin wallet that deployed the market. Users can then call `claimWinnings()` to collect their payout.

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
│ 0xa478…7cbb0      │    sellYes/sellNo()
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
