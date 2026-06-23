import fs from 'fs';
import 'dotenv/config';
import { createWalletClient, createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { arcTestnet } from 'viem/chains';

// Sweep all USDC from the faucet wallets into the treasury.
// On Arc, USDC is the native gas token (native balance == ERC-20 0x3600, same
// pool), so a plain value transfer moves USDC; we leave a tiny gas reserve.
//   Preview:  DRY=1 node sweep-faucet-wallets.mjs
//   Execute:        node sweep-faucet-wallets.mjs
const TREASURY = '0xD138925168aD03fEe0Cca73cD949F1077C82c093';
const FILE = process.argv[2] || 'C:\\Users\\User\\Documents\\Projects\\Arc\\Puls\\.agents\\wallets with usdc.txt';
const DRY = process.env.DRY === '1';
const rpc = http(process.env.ARC_RPC_URL || undefined);
const pc = createPublicClient({ chain: arcTestnet, transport: rpc });

const keys = fs.readFileSync(FILE, 'utf-8')
  .split(/\r?\n/)
  .map((l) => l.match(/Private key:\s*([0-9a-fA-Fx]+)/i)?.[1])
  .filter(Boolean)
  .map((k) => (k.startsWith('0x') ? k : `0x${k}`));

const fmt = (wei) => (Number(wei) / 1e18).toFixed(6);

async function main() {
  console.log(`${keys.length} wallets · ${DRY ? 'DRY RUN (no transfers)' : 'LIVE SWEEP'} → ${TREASURY}\n`);
  const gasPrice = await pc.getGasPrice();
  const reserve = 21000n * gasPrice * 5n; // generous gas reserve for a value transfer
  let found = 0n, swept = 0n, sent = 0, skipped = 0, failed = 0;

  for (const pk of keys) {
    const acct = privateKeyToAccount(pk);
    let bal;
    try { bal = await pc.getBalance({ address: acct.address }); }
    catch (e) { console.log(`  ${acct.address}  balance read failed: ${e.shortMessage || e.message}`); failed++; continue; }
    found += bal;
    if (bal <= reserve) { skipped++; continue; }
    const value = bal - reserve;
    if (DRY) {
      console.log(`  ${acct.address}  ${fmt(bal)} USDC  → would send ${fmt(value)}`);
      swept += value;
      continue;
    }
    try {
      const wc = createWalletClient({ account: acct, chain: arcTestnet, transport: rpc });
      const hash = await wc.sendTransaction({ to: TREASURY, value });
      await pc.waitForTransactionReceipt({ hash });
      swept += value;
      sent++;
      console.log(`  ${acct.address}  sent ${fmt(value)} USDC  tx ${hash}`);
    } catch (e) {
      failed++;
      console.log(`  ${acct.address}  send failed: ${e.shortMessage || e.message}`);
    }
  }

  console.log(`\nTotal found: ${fmt(found)} USDC across ${keys.length} wallets`);
  console.log(DRY ? `Would sweep: ${fmt(swept)} USDC (skipped ${skipped} dust)` 
                  : `Swept: ${fmt(swept)} USDC · sent ${sent} · skipped ${skipped} dust · failed ${failed}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
