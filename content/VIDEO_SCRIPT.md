# Puls Demo Video — Shooting Script

_Target: <3 minutes. RDM records screen + phone + voiceover. Follow this script beat by beat._

---

## Pre-flight checklist

- [ ] VPS: `COPY_TRADE_ENABLED=true`, `TIPS_ENABLED=true`, `ALPHA_PAID_ENABLED=true` (Claude will enable before recording)
- [ ] Demo wallets funded: seller `0xa93F…894e` ≥ 10 USDC, buyer `0x08ea…344E` ≥ 5 USDC, treasury ≥ 100 USDC
- [ ] Browser: Chrome, dark mode, 1440px viewport, logged in to pulsmarket.tech as demo user
- [ ] Phone: pulsmarket.tech in Chrome, logged in via Google
- [ ] Terminal: `cd puls_backend && node scripts/x402-buyer.mjs` ready
- [ ] Tabs open: pulsmarket.tech, testnet.arcscan.app/address/0xa93FFcC230d1bd6f6b0a23a7f8BEcc2C9ECD894e (seller page)

---

## Beat 1 — HOOK (0:00–0:20)

**Screen:** Terminal (full screen)

**Action:**
1. Run `node scripts/x402-buyer.mjs`
2. Wait for output: payment settled, receipt ID printed

**Voiceover:**
> "This agent just paid another creator a tenth of a cent for a forecast. Settled on Arc, real USDC, 573 milliseconds."

**Cut to:** arcscan seller address page — show the USDC transfer arriving

**Voiceover (continued):**
> "Every payment on-chain. Every receipt verifiable."

**Notes:**
- Show the seller ADDRESS page, NOT tx/uuid (Gateway batches async → uuid 404s)
- receiptId = Circle transfer UUID (copy from terminal output)

---

## Beat 2 — PHONE SWIPE TRADE (0:20–0:50)

**Screen:** Phone recording

**Action:**
1. Open pulsmarket.tech
2. Show Google sign-in → wallet auto-created (no seed phrase)
3. Swipe through 2-3 markets (show the swipe UX)
4. Place a YES trade on a market → show confirmation

**Voiceover:**
> "Puls is a live prediction market on Arc. Sign in with Google, get a Circle wallet, trade in seconds. No gas, no seed phrase. Swipe to trade on what happens next."

**Notes:**
- Swipe should feel smooth — show the card animation
- Trade confirmation should show the confetti burst
- Keep phone steady, good lighting

---

## Beat 3 — ECONOMY EXPLORER + EARNINGS (0:50–1:40)

**Screen:** Desktop browser

**Action:**
1. Show Economy Explorer tab — live feed of nanopayments on arcscan
2. Click into a payment → show arcscan page with USDC transfer
3. Switch to Earnings tab — show the receipt list
4. Show "On-chain settlements" link → opens seller address on arcscan

**Voiceover:**
> "Forecasters are creators. They're paid per read, per copied trade, per tip — priced by their on-chain win rate. Every payment settles on Arc, and every receipt is right here in the app."

**Notes:**
- Earnings tab shows real receipts (2 settled payments from x402-buyer.mjs)
- Point out the "Circle-settled" badge and receiptId

---

## Beat 4 — LEADERBOARD + ALPHA + COMMENTS (1:40–2:10)

**Screen:** Desktop browser

**Action:**
1. Show Leaderboard tab — Pulse 🤖 at ~92% win rate at the top
2. Point out humans vs agents on the same board
3. Switch to Agent → Alpha tab — show a paid analysis teaser
4. Click "Read for $0.001" → show unlock flow
5. Show comment thread below the analysis

**Voiceover:**
> "Humans and AI agents compete on one leaderboard. Our house agent Pulse has a 92% win rate. Read top forecasts for a tenth of a cent, discuss them in the thread, tip the best calls. The smallest unit of insight is finally sellable."

**Notes:**
- Pulse 🤖 is the star — 92% win rate, 62+ trades
- Alpha unlock = real x402 payment → Earnings receipt appears
- Comment thread shows the community layer

---

## Beat 5 — TRACTION + STACK (2:10–2:50)

**Screen:** Static slide or desktop with overlay text

**Content on screen:**
- Users: [X] sign-ups
- Trades: [Y] agent trades
- Nanopayments: [Z] x402 settlements
- Copy-trade followers: [N] active
- Stack: Circle SCA Wallets · Gateway x402 · Agent Wallets · Arc Testnet

**Voiceover:**
> "[X] users, [Y] agent trades, [Z] nanopayments settled. Built on the full Circle stack: SCA gasless wallets, Gateway x402, Agent Wallets — all settled on Arc."

**Notes:**
- Update numbers from Supabase on recording day
- Show the stack logos if possible

---

## Beat 6 — CTA (2:50–3:00)

**Screen:** Puls logo + URL

**Action:** Show pulsmarket.tech landing page or logo

**Voiceover:**
> "Puls. The forecast economy. pulsmarket.tech."

**Notes:**
- Keep it clean, 10 seconds max
- URL clearly visible

---

## Post-production

- Total runtime: 2:50–3:00
- Add light background music (royalty-free, low volume)
- Cut cleanly between beats — no dead air
- Export 1080p, upload YouTube unlisted
- Take 3-4 screenshots for docs and submission

---

## Flags to enable before recording (Claude/RDM)

```bash
# On VPS (.env):
COPY_TRADE_ENABLED=true
TIPS_ENABLED=true
ALPHA_PAID_ENABLED=true

# After recording, revert:
COPY_TRADE_ENABLED=false
```

## Troubleshooting

- **x402-buyer.mjs fails:** Check buyer balance at faucet.circle.com, ensure Gateway deposit worked
- **Pulse not trading:** Check PM2 logs, ensure cron is running
- **Arcscan shows nothing:** Wait 30s — Gateway batches are async, USDC lands on next flush
