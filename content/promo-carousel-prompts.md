# Promo Carousel — AI Image Prompts

_By Claude, 2026-06-16. For the Home-screen promo carousel._

**Brand:** Puls — premium glassmorphism, dark mode, violet `#8b5cf6` + pink `#ec4899` accents, Arc/USDC-native.

**Usage rules:**
- 16:9 (mobile banner) or 2:1 (wide carousel card). HD / 1920×1080.
- **No text in the image** — overlay copy in-app (Flutter `Stack` + `Text`) so wording changes without regen and avoids garbled AI letters.
- For a consistent set: same seed/style across slides (Midjourney `--style raw` + shared `--sref`, or `--ar 16:9`).
- Keep the focal subject on one third of the frame → clean space for text + CTA button.

---

## Slide 1 — Refer a Friend (no auto-payout: "invite & climb")
```
A premium fintech promotional banner, 16:9 aspect ratio, dark mode. Two glowing 3D abstract figures connected by a luminous arc of light, symbolizing friend referral and connection. Floating translucent glass cards with subtle USDC coin motifs drifting in the background. Deep navy-to-black gradient backdrop with vibrant violet (#8b5cf6) and pink (#ec4899) accent glow, soft bokeh, glassmorphism, neon rim lighting. Clean negative space on the left third for text overlay. Cinematic, high detail, polished, modern crypto app aesthetic. No text, no letters, no words.
```
Overlay copy idea: **"Refer a friend — climb the leaderboard together"** (no auto USDC payout; testnet).

## Slide 2 — World Cup 2026 Predictions
```
A dynamic premium sports-prediction banner, 16:9, dark mode. A glowing soccer ball mid-air dissolving into luminous data particles and upward-trending prediction graph lines, energetic motion. Stadium lights bokeh in the deep background. Deep black-to-navy gradient with electric violet (#8b5cf6) and pink (#ec4899) neon accents, glassmorphism panels, holographic glow. Negative space on the right for text overlay. Cinematic, high detail, futuristic betting-market aesthetic, World Cup 2026 energy. No text, no letters, no words, no team logos.
```
Overlay copy idea: **"World Cup 2026 — make your call"**.

## Slide 3 — Follow us on X / Don't miss news
```
A sleek social-media promo banner, 16:9, dark mode. A glowing 3D notification bell and a stylized abstract "X" social glyph floating among translucent glass UI cards and drifting light particles. Subtle broadcast/signal wave rings emanating outward. Deep navy-black gradient background with violet (#8b5cf6) to pink (#ec4899) gradient glow, glassmorphism, neon rim light, premium polish. Clean area for text overlay centered-left. Modern, cinematic, crypto-app marketing aesthetic. No text, no letters, no words.
```
Overlay copy idea: **"We're on X — don't miss the alpha. Follow @rdmnad"**.

## Slide 4 (optional) — Paid Alpha / forecaster economy (core narrative)
```
A premium banner, 16:9, dark mode. A glowing crystal/gem representing premium insight, with a stream of tiny USDC coin particles flowing from it toward a stylized creator avatar, symbolizing "paid per read" nanopayments. Floating glass analysis cards with upward graph lines. Deep black-navy gradient, violet (#8b5cf6) and pink (#ec4899) neon glow, glassmorphism, cinematic depth. Negative space top-left for text. High detail, modern fintech aesthetic. No text, no letters, no words.
```
Overlay copy idea: **"Read top forecasts for $0.001 — paid straight to the creator"**.

---

**Note (compliance):** all USDC is testnet. Any "earn" framing on slides must say testnet in small print; referral has **no automatic USDC payout** (decided 2026-06-16) — invite + leaderboard climb only, to avoid abuse/farming on AMA.
