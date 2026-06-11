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

# UMA Optimistic Oracle resolution (optional — defaults to legacy direct resolve)
UMA_RESOLUTION=false                                          # flip to true to resolve new markets via UMA OOV2
UMA_ADAPTER_ADDRESS=0x013675668842505839fdc581f56746593fDAB85D # UMAResolverAdapter on Arc Testnet
UMA_OOV2_ADDRESS=0x363dF46534b9b7764C49504aDE0F7c8DD3c82Cae    # OptimisticOracleV2 on Arc Testnet
```

## UMA resolution mode

With `UMA_RESOLUTION=true`, newly deployed markets are owned by the
`UMAResolverAdapter` and the 5-minute cron acts as a *proposer bot*:

1. after the market deadline it opens a price request on the Optimistic Oracle,
2. once the Polymarket consensus outcome is determinable it proposes it
   (posting a 1 USDC bond that is returned on settlement),
3. after the 10-minute dispute window passes undisputed it settles the request,
   which resolves the market on-chain through the adapter.

Markets created before the flag was flipped are not registered with the adapter
and automatically fall back to the legacy direct-resolve path. Disputed
proposals escalate to the DVM (mock oracle on testnet) and can be force-decided
via the adapter's `adminResolve` escape hatch (also used by
`POST /api/market/resolve` for adapter-owned markets).

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/wallet/get-or-create` | Auto-create Circle wallet for user |
| GET | `/api/wallet/balance` | Get USDC balance |
| GET | `/api/wallet/export` | Get wallet info |
| POST | `/api/trade/buy` | Buy YES/NO with USDC |
| GET | `/api/trade/status` | Poll transaction state |
| GET | `/api/portfolio` | Get user trade history |
