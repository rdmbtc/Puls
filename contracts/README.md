# Puls Contracts

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
