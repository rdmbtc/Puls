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
