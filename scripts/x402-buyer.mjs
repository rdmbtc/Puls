/**
 * Puls x402 buyer demo — an agent pays a creator for one premium forecast via
 * Circle Gateway nanopayments on Arc Testnet, then prints the on-chain proof.
 *
 * This is the "buyer (human or agent)" side of the creator loop. It mirrors
 * Circle's official `arc-nanopayments` buyer (`agent.mts`), trimmed to a single
 * paid request so it's easy to demo and screenshot.
 *
 * ⚠️ Gateway settlement is ASYNC-BATCH: `settle()` returns a Circle transfer
 * UUID, NOT an on-chain tx hash. The on-chain USDC lands on the SELLER address
 * once Circle flushes the batch — so we print the seller's arcscan address page
 * (where the transfer becomes visible), not `arcscan/tx/<uuid>` (which 404s).
 *
 * Prereqs (.env on the server, NEVER in git/chat):
 *   BUYER_PRIVATE_KEY     funded wallet — top up via https://faucet.circle.com
 *                         (testnet USDC; on Arc, gas is native USDC too)
 *   BASE_URL              backend base (default http://localhost:3000)
 *   DEPOSIT_AMOUNT        USDC to deposit into Gateway Wallet (default "0.5")
 *   X402_SELLER_ADDRESS   (optional) seller/creator address, for the proof link
 *
 * Run on the server (see scripts/X402_BUYER_README.md):
 *   node scripts/x402-buyer.mjs
 */
import 'dotenv/config';
import { GatewayClient } from '@circle-fin/x402-batching/client';

const BASE_URL = (process.env.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const DEPOSIT_AMOUNT = process.env.DEPOSIT_AMOUNT || '0.5';
const SELLER = process.env.X402_SELLER_ADDRESS || '';
const buyerKey = process.env.BUYER_PRIVATE_KEY;

if (!buyerKey) {
  console.error('Missing BUYER_PRIVATE_KEY. Generate a wallet and fund it via https://faucet.circle.com');
  process.exit(1);
}

const RESOURCE = `${BASE_URL}/api/alpha/sample`;

async function main() {
  const gateway = new GatewayClient({
    chain: 'arcTestnet',
    privateKey: buyerKey.startsWith('0x') ? buyerKey : `0x${buyerKey}`,
  });

  console.log('Checking balances...');
  let balances = await gateway.getBalances();
  console.log(`  wallet USDC:   ${balances.wallet?.formattedBalance ?? balances.wallet?.balance}`);
  console.log(`  gateway avail: ${balances.gateway?.formattedAvailable ?? balances.gateway?.available}`);

  // Deposit into the Gateway Wallet if available balance is thin.
  if (!balances.gateway?.available || balances.gateway.available < 100_000n) {
    console.log(`Depositing ${DEPOSIT_AMOUNT} USDC into Gateway Wallet...`);
    const dep = await gateway.deposit(DEPOSIT_AMOUNT);
    console.log(`  deposit tx: ${dep.depositTxHash}`);
    balances = await gateway.getBalances();
    console.log(`  gateway avail now: ${balances.gateway?.formattedAvailable ?? balances.gateway?.available}`);
  }

  console.log(`\nAgent paying for a premium forecast: GET ${RESOURCE}`);
  const start = Date.now();
  const result = await gateway.pay(RESOURCE, { method: 'GET' });
  const ms = Date.now() - start;

  console.log(`\n✅ Paid ${result.formattedAmount ?? ''} USDC in ${ms}ms`);
  if (result.payer) console.log(`   buyer (payer):     ${result.payer}`);

  // ⚠️ result.transaction here is a CIRCLE TRANSFER RECEIPT (UUID), not an on-chain hash.
  if (result.transaction) {
    console.log(`   Circle receipt id: ${result.transaction}`);
    console.log(`   (async batch — this is a Circle transfer id, NOT an arcscan tx hash)`);
  }

  // On-chain proof = the seller address page, where the batched USDC lands.
  const seller = SELLER || result.payTo || result.recipient;
  if (seller) {
    console.log(`\n🔗 On-chain proof (USDC arrives here after Circle flushes the batch):`);
    console.log(`   https://testnet.arcscan.app/address/${seller}`);
  } else {
    console.log(`\n🔗 Set X402_SELLER_ADDRESS to print the seller's arcscan proof link.`);
  }

  console.log('\n--- forecast payload (the thing we just bought) ---');
  console.log(JSON.stringify(result.data ?? result.body ?? result, null, 2));
}

main().catch((err) => {
  console.error('Buyer demo failed:', err?.message || err);
  process.exit(1);
});
