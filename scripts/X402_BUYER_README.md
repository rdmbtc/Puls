# x402 buyer demo — agent pays a creator (for the video hook)

`scripts/x402-buyer.mjs` makes one **live Circle Gateway x402** payment from an agent wallet to the Puls creator endpoint `GET /api/alpha/sample` ($0.001), then prints on-chain proof. This is the cleanest pure-Gateway rail (the buyer holds its own EOA key), perfect for the 0:00–0:20 video hook.

> In-app human payments (alpha unlock / copy-fee / tip) use a different rail — a direct gasless USDC transfer from the user's Circle SCA wallet — because SCA wallets can't sign client-side x402. See `docs.pulsmarket.tech/creator-economy/payment-flows`.

## One-time setup (on the VPS / locally with Node ≥ 20)

1. **Deps** (already installed on the server):
   ```bash
   npm install   # needs @circle-fin/x402-batching + peers @x402/core @x402/evm
   ```
2. **Env** — in `.env` (NEVER commit; keys live only in `/opt/puls-backend/.env`):
   ```ini
   BUYER_PRIVATE_KEY=0x...        # a fresh EOA, NOT the treasury key
   BASE_URL=https://84-22-148-57.sslip.io   # or http://localhost:3000
   DEPOSIT_AMOUNT=0.5             # USDC to pre-fund the Gateway Wallet
   X402_SELLER_ADDRESS=0xa93F...  # so the proof link points at the seller page
   ```
3. **Fund the buyer**: send testnet USDC to the buyer address via https://faucet.circle.com (on Arc, USDC is also the gas token, so the same balance covers gas).

## Run

```bash
node scripts/x402-buyer.mjs
```

Expected output:
- balances, then `✅ Paid 0.001 USDC in <ms>`
- a **Circle receipt id** (UUID) — this is the batch transfer id, *not* an arcscan tx hash
- an **arcscan address link** for the seller, where the USDC appears once Circle flushes the batch
- the forecast JSON payload that was unlocked by the payment

## Gotchas (learned the hard way)

- **`authorization_validity_too_short`** → the server's 402 must advertise `maxTimeoutSeconds ≥ 691200` (Gateway requires ≥ 7-day validity). This is fixed server-side in `lib/x402.js`; the buyer derives validity from the 402, so no change needed here.
- **Don't open `arcscan/tx/<uuid>`** — it 404s. Settlement is async-batch; show the seller **address** page instead.
- Settlement timing: the on-chain transfer may take a short while to appear after the batch flushes; record the payload + receipt immediately, capture the address page once it lands.
