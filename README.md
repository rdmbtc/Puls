# Puls

**Mobile-first prediction market built on Arc Testnet.**

Users sign in with Google → get a Circle MPC wallet instantly → trade real Polymarket predictions with USDC as gas. No ETH, no seed phrase, no friction.

---

## Demo

| Feed | Fast Buy | Portfolio |
|------|----------|-----------|
| Live Polymarket odds | Swipe YES/NO instantly | Real USDC trades on-chain |

---

## Stack

| Layer | Tech |
|-------|------|
| Mobile | Flutter (Android) |
| Auth | Supabase + Google OAuth |
| Wallets | Circle Developer-Controlled Wallets (MPC) |
| Blockchain | Arc Testnet (Chain ID 5042002) |
| Gas token | USDC — no ETH needed |
| Market data | Polymarket Gamma API (public, no auth) |
| Backend | Node.js on VPS |
| Smart contract | Solidity 0.8.24 on Arc Testnet |

---

## Smart Contract

**LMSRMarketFactory** — factory for prediction markets.

- Address: `0x18aa351799665a81a2c20099fa7d7a82199305b7`
- Explorer: [testnet.arcscan.app](https://testnet.arcscan.app/address/0x18aa351799665a81a2c20099fa7d7a82199305b7)
- Source: `contracts/src/LMSRMarketFactory.sol`

---

## Features

- **Google sign-in** → Circle MPC wallet created automatically
- **Live feed** — 100 real Polymarket markets, deployed-first ordering for instant trades
- **Fast Buy** — swipe right/left to buy YES/NO instantly (no confirmation modal)
- **TikTok Home** — vertical video feed with prediction pills
- **Real trades** — USDC sent to smart contract on Arc Testnet
- **Portfolio** — real trade history with Arc explorer links
- **Dark/light theme** — Dynamic Island floating nav bar
- **Autonomous AI Trading Agent** — budget-capped strategy presets (Arbitrage, DCA) executing trades on-chain
- **Automated Oracle Resolution** — 5-minute cron check polling Polymarket consensus outcomes and settling contracts on-chain automatically

---

## Setup

### Prerequisites
- Flutter SDK
- Node.js 20+
- Circle API key ([console.circle.com](https://console.circle.com))
- Supabase project ([supabase.com](https://supabase.com))

### 1. Clone
```bash
git clone https://github.com/rdmbtc/puls.git
cd puls
```

### 2. Flutter app
```bash
# Copy secrets template
cp lib/core/secrets.dart.example lib/core/secrets.dart
# Fill in your Supabase URL and anon key in secrets.dart

flutter pub get
flutter run
```

### 3. Backend
```bash
cd backend
cp .env.example .env
# Fill in Circle API key, entity secret, Supabase service key

# Run Supabase schema (paste supabase-schema.sql in Supabase SQL Editor)

node server.js
```

### 4. Get testnet USDC
[faucet.circle.com](https://faucet.circle.com) → Arc Testnet → paste your wallet address

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
│ (VPS)        │                 │ (Arc Testnet)         │
└──────┬───────┘                 │ • No seed phrase      │
       │                         │ • Instant on sign-up  │
       │ createMarket()          └──────────┬────────────┘
       ▼                                    │ USDC (gas token)
┌───────────────────┐    buyYes/buyNo()     │
│ LMSRMarketFactory │ ◁────────────────────-┘
│ 0xa478b966…7cbb0  │
└───────┬───────────┘
        │ creates
        ▼
┌──────────────────┐     verified source     ┌──────────────────┐
│ PulsMarket.sol   │ ─────────────────────▷  │ Arcscan Explorer │
│ (per-question)   │                         │ Chain ID 5042002 │
└──────────────────┘                         └──────────────────┘

Key: USDC is the ONLY token. No ETH needed. Sub-second finality.
```

---

## Backend

Separate repo: [github.com/rdmbtc/puls_backend](https://github.com/rdmbtc/puls_backend)

---

## Built on Arc

Arc is Circle's stablecoin-native L1 where USDC is the gas token. Puls uses Arc because:
- Users pay gas in USDC — no ETH needed
- Sub-second finality for instant trade confirmation  
- Circle's full-stack ecosystem (wallets, USDC, compliance)

[arc.network](https://arc.network) · [Arc Blueprint: Prediction Markets](https://arc.network/blog/prediction-markets)
