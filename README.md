# puls_backend

Node.js backend for [Puls](https://github.com/rdmbtc/puls) — a prediction market app built on Arc Testnet.

## Stack
- Express.js
- Circle Developer-Controlled Wallets SDK
- Arc Testnet (Chain ID 5042002, USDC as gas)

## Setup

```bash
npm install
cp .env.example .env
# Fill in your keys
node server.js
```

## Environment Variables

```
CIRCLE_API_KEY=
CIRCLE_ENTITY_SECRET=
CIRCLE_APP_ID=
MARKET_CONTRACT=0xca048d69BaA38C6364d3E107c2b389BB8D1320dB
WALLET_SET_ID=
PORT=3000
```

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/wallet/get-or-create` | Auto-create Circle wallet for user |
| GET | `/api/wallet/balance` | Get USDC balance |
| GET | `/api/wallet/export` | Get wallet info |
| POST | `/api/trade/buy` | Buy YES/NO with USDC |
| GET | `/api/trade/status` | Poll transaction state |
| GET | `/api/portfolio` | Get user trade history |
