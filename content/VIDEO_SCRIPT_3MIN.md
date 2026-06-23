# Puls — 3-Minute Submission Video (music-only, no voice-over)

_Total runtime: **3:00**. No narration — **on-screen captions carry the story**, timed to music. Show pulsmarket.tech + two narrated terminal scripts + on-chain proof on Arcscan._

---

## 🎵 Music prompt (for AI music generator — ≈440 chars, 3 min)

```
Sleek futuristic fintech product-film instrumental, 3 min, no vocals. Modern cinematic electronic: warm analog synth pulses, crisp four-on-the-floor beat, bright arpeggios, deep sub-bass, subtle glitch textures. Mood: confident, optimistic, money-in-motion. Atmospheric intro (0:00-0:30), steady rising build, driving energetic peak (1:30-2:30), triumphant bright resolve, clean fade-out. ~115 BPM. Polished, premium, hopeful — Apple-meets-crypto launch vibe.
```

Music arc → video arc: **intro** under the hook, **build** through product + swarm, **peak/drop** on the AgentBond slash, **triumphant resolve** on traction + close.

---

## ✅ Pre-flight checklist (before you hit record)

- [ ] **(Recommended) Rotate LLM keys** in `/opt/puls-backend/.env` so the agent's STEP 2 shows real `DECISION [LLM (model)]` reasoning instead of the deterministic fallback. (Backend is in 429 right now.)
- [ ] **Backend healthy** — already verified: treasury 1351 USDC, buyer `0x08ea…344E` 19.5 USDC + Gateway 0.495, RPC/Supabase/Circle green.
- [ ] **Browser**: Chrome, dark mode, 1440px, logged into pulsmarket.tech (incognito to dodge the service worker / stale cache).
- [ ] **Phone**: pulsmarket.tech open, logged in via Google.
- [ ] **Terminal 1 (VPS)**: SSH in, sitting at `cd /opt/puls-backend`.
- [ ] **Terminal 2 (local)**: sitting at `cd contracts`.
- [ ] **Tabs open**: pulsmarket.tech · /pulse · /agent · /versus · /stats · `testnet.arcscan.app/address/0xa93FFcC230d1bd6f6b0a23a7f8BEcc2C9ECD894e` (seller). Open the AgentBond tx links live from the terminal during the shoot.

**Scripts are uploaded & verified working:**
- VPS: `/opt/puls-backend/scripts/demo-narrated-agent.mjs`
- Local: `contracts/demo-narrated-agentbond.mjs`

---

## 🎬 Shot list — beat by beat (3:00)

> Captions are the exact on-screen text (English). Record each terminal script in full, then trim/speed in edit to fit the beat.

### BEAT 1 — HOOK · agent pays agent (0:00–0:18) · TERMINAL (VPS)
**Run:**
```bash
cd /opt/puls-backend && DEMO_PAUSE_MS=900 node scripts/demo-narrated-agent.mjs
```
Show the title banner + STEP 1: `HTTP 402 Payment Required` → `PAID 0.001 USDC in ~650 ms — one AI just paid another AI`.

**Caption:** `Two AI agents. No human. One just paid the other for a forecast — in USDC, on Arc.`

---

### BEAT 2 — reason → decide → proof (0:18–0:35) · TERMINAL → ARCSCAN
Let the same script roll through STEP 2 (decision + why), STEP 3 (`EXPECTED PnL NET OF COST: +0.047 USDC`), STEP 4 (proof link). Cut to the seller's Arcscan **address** page.

**Caption:** `It reasons, decides, and profits net of what it paid. Every payment verifiable on-chain.`

---

### BEAT 3 — onboarding + swipe (0:35–0:55) · PHONE
Google sign-in → Circle wallet appears (no seed phrase) → swipe through 2–3 markets → place a YES trade → confetti confirm.

**Caption:** `Sign in with Google. Get a wallet instantly. Swipe to trade. USDC is the gas — no ETH, no seed phrase.`

---

### BEAT 4 — the living swarm (0:55–1:18) · WEB `/pulse` → `/agent`
Scroll the live agent feed: research → bought signal → decision → trade; the swarm-memory line (`memory → 3-0, 100% win rate`); an agent comment. Then the `/agent` decision trace.

**Caption:** `11 AI agents live in production — they research the web, pay each other, trade, and show their reasoning.`

---

### BEAT 5 — humans vs agents + AI Oracle (1:18–1:40) · WEB `/versus` → a market
Show the leaderboard with humans and 🤖 agents ranked together. Open a market → AI Oracle consensus shown beside the crowd (Polymarket) probability.

**Caption:** `Humans and AI compete on one leaderboard. An AI Oracle prices every market beside the crowd.`

---

### BEAT 6 — creator economy (1:40–2:05) · WEB blog → signal unlock → earnings
Open the Puls Journal (a daily AI analysis post) → a creator Signal with its on-chain attestation → unlock for $0.001 / tip → the Earnings tab receipts.

**Caption:** `Forecasters are creators. Signals are attested on-chain; readers pay per unlock, tip, and copy — settled on Arc.`

---

### BEAT 7 — skin in the game · AgentBond (2:05–2:38) · TERMINAL (local) → ARCSCAN
**Run:**
```powershell
cd contracts ; $env:DEMO_PAUSE_MS='1100' ; node demo-narrated-agentbond.mjs
```
_(bash: `cd contracts && DEMO_PAUSE_MS=1100 node demo-narrated-agentbond.mjs`)_

Show STEP 3 **SLASHED** and STEP 5 **RETURNED**; click a fresh `arcscan/tx/0x…` link live. **Sync the slash moment to the music peak.**

**Caption:** `Agents stake USDC on every call. Wrong → slashed on-chain. Right → returned. Reputation as capital at risk.`

---

### BEAT 8 — traction (2:38–2:55) · WEB `/stats`
Live counters (refresh on shoot day from `/api/stats`).

**Caption:** `6,900+ trades · 1,180+ agent trades · 920 USDC nanopayments · 296 markets resolved — all live, all verifiable.`

---

### BEAT 9 — close (2:55–3:00) · LOGO + URL
Puls logo, clean.

**Caption:** `Puls — the agentic prediction economy on Arc.  pulsmarket.tech`

---

## ⏱ Pacing notes
- Default line-pause is `DEMO_PAUSE_MS=1700`. Suggested for shoot: **900** (agent demo, fast hook) and **1100** (AgentBond, let the on-chain steps breathe).
- Each run produces **fresh** tx hashes (AgentBond spins up a new agent address every run) — open the link straight from the terminal in-frame.
- x402 (Beats 1–2) settles in async batches → proof = the seller **address** page (USDC lands after the flush), **not** `tx/<uuid>`. AgentBond (Beat 7) gives **instant** `tx/<hash>` links.

## 🎞 Post-production
- Music only, low headroom; cut on the beat, no dead air.
- Burn in the captions above (sans-serif, high contrast, lower-third or center).
- Optional: brief "Arc · USDC-as-gas · Circle Gateway · ERC-8004" tech badges in Beat 9.
- Export 1080p (or 4K), upload unlisted, grab 3–4 stills for the submission.
