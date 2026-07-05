# Puls Contracts

**Mobile-first prediction market built on [Arc](https://arc.network) — Circle's stablecoin-native L1 where USDC is the gas token.**

Sign in with Google → get a Circle MPC wallet instantly → swipe to trade real predictions with **USDC as gas**. No ETH, no seed phrase, no friction, sub-second finality. And it's the first prediction market where **AI agents are full economic actors** — they research the open web, trade on-chain, price markets, and pay each other for alpha in USDC.

🌐 **Live app:** [pulsmarket.tech](https://pulsmarket.tech)
▶️ **Video Demo:** [Watch on YouTube](#) <!-- Add video link here -->
🚀 **Run in 2 mins:** `git clone https://github.com/rdmbtc/Puls.git && cd Puls && npm i && npm run dev`

## Circle Primitives Integration
| # | Primitive | Integrated? | Primary evidence |
|---|-----------|-------------|------------------|
| 1 | Circle Gateway / Nanopayments | YES | `lib/x402.js:18,41,128,136`; `scripts/x402-buyer.mjs:25,40`; `scripts/agent-loop.mjs:31,112` |
| 2 | x402 protocol | YES (real middleware; 2 endpoints do full handshake) | `lib/x402.js:89-186`; `server.js:2950,6252` |
| 3 | Circle Wallets (dev-controlled SCA) | YES (core) | `server.js:295-298,1059-1064,1196-1200`; `createContractExecutionTransaction` across `lib/*` |
| 4 | App Kit / Bridge / Swap / Unified Balance | PARTIAL (App Kit Swap only) | `lib/swap.js:33-39,85,112`; no bridge-kit/swap-kit/unified-balance |
| 5 | USDC / EURC on Arc | YES | `server.js:305`; `lib/swap.js:24`; 6-dp math throughout |
| 6 | Arc chain config | YES | `server.js:12,319-331,1431`; `.env.example:110-112` (Canteen) |
| 7 | Puls on-chain contracts | YES | `contracts/src/{SignalRegistry,AgentBond,StreamingPay,LMSRMarket,LMSRMarketFactory,PulsMarket,UMAResolverAdapter}.sol` + `deploy*.mjs` |
| 8 | ERC-8004 identity/reputation | YES (identity live) | `server.js:4599-4696,4969,6746,6818`; `lib/agent_swarm.js:255` |

> **Honesty notes for the audit:** 
> **(a)** Most in-app "nanopayments" are direct Circle SCA USDC transfers logged into `x402_payments`, while the true `x402` protocol handshake runs *only* on `/api/alpha/sample` and `/api/agent/director`. 
> **(b)** The `StreamingPay.sol` contract is deployed and tested, but the live streaming path uses batched SCA transfers rather than the contract. 
> Both are defensible design choices (SCA wallets can't client-sign x402 directly), but we call them out precisely here rather than claiming every receipt is a Gateway settlement.

---


Solidity contracts for Puls prediction markets on Arc Testnet (Chain ID 5042002, USDC gas).

- `src/LMSRMarket.sol` — LMSR binary prediction market (v2: slippage protection, price views, emergency exit)
- `src/LMSRMarketFactory.sol` — factory that deploys + funds markets
- `src/PulsMarket.sol` — legacy CPMM market

## Setup

Install [Foundry](https://book.getfoundry.sh/getting-started/installation), then fetch dependencies (not committed — see `remappings.txt`):

```bash
git clone --depth 1 https://github.com/foundry-rs/forge-std lib/forge-std
git clone --depth 1 https://github.com/PaulRBerg/prb-math lib/prb-math
```

## Test

```bash
forge test
```

## LMSRMarket v2 notes

- `buyYes(amount, minSharesOut)` / `sellYes(shares, minUsdcOut)` (and NO variants) revert on slippage; single-arg legacy signatures remain for backward compatibility.
- `getYesPrice()` / `getNoPrice()` return the marginal price as a 6-decimal probability (`500000` = $0.50).
- Trading (buys **and** sells) closes at `deadline`.
- If a market is never resolved, traders can call `emergencyRedeem()` after `deadline + 30 days` to exit pro-rata against the contract balance.
- All USDC transfers check return values.

## Deploy

```bash
node deployFactory.mjs   # deploys LMSRMarketFactory
```

Markets are then created lazily by the backend via `factory.createMarket(slug, deadline, b)`.

## UMA Optimistic Oracle resolution (v3)

`src/UMAResolverAdapter.sol` bridges LMSR markets to UMA's Optimistic Oracle V2 for
decentralized, disputable resolution. The backend hands ownership of each new market
to the adapter; after the deadline anyone can request resolution, a proposer posts the
outcome with a USDC bond, and once the dispute window (liveness) passes undisputed,
anyone can settle — the adapter then calls `market.resolve(outcome)`. Disputes escalate
to the DVM (mock oracle on Arc Testnet). Admin escape hatches: `adminResolve`,
`reclaimMarket`.

### Arc Testnet deployments (all verified on Arcscan)

| Contract | Address |
| --- | --- |
| LMSRMarketFactory (v2) | `0x92c2fd35c0f1a501993be8e0fdae7caa34a8b80b` |
| UMAResolverAdapter | `0x013675668842505839fdc581f56746593fDAB85D` |
| OptimisticOracleV2 | `0x363dF46534b9b7764C49504aDE0F7c8DD3c82Cae` |
| Finder | `0x413ffcC8B552Ca2247442D05dDDb7B23994AC9D2` |
| IdentifierWhitelist | `0x08967F8390fB6504691619e36b0DC0A84835b828` |
| AddressWhitelist (collateral) | `0xe974a6859E06256986f47caFdE1e4785C00589eF` |
| Store | `0x0d7957929B464d6ff5fc8D01769aD450B92c5F3E` |
| MockOracleAncillary (DVM) | `0xd3985ed3386266069d68148339DCC56a28fE6793` |

Identifier: `YES_OR_NO_QUERY` · bond currency: USDC (`0x3600…0000`) · proposer bond: 1 USDC · liveness: 600s.
The UMA stack was compiled from `@uma/core` sources with solc 0.8.34 (see circlefin/arc-prediction-markets for the original bootstrap pattern).
