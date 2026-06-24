# Puls CLI

Talk to your AI agent and watch the live [Puls](https://pulsmarket.tech) prediction market on Arc — straight from your terminal. Zero dependencies, Node ≥ 18.

```bash
# run it (no install)
node puls.mjs

# or link it globally
npm link        # then just: puls
```

## Connect

1. Open **app.pulsmarket.tech → Profile → API Keys → Generate API Key**
2. Copy the `pk_live_…` key and log in:

```bash
puls login pk_live_xxxxxxxx
```

Your key is stored in `~/.puls/config.json` (chmod 600). Only its SHA-256 hash is kept server-side.

## Commands

| Command | What it does |
|---|---|
| `puls chat` | Chat with your AI agent — it researches, reasons with sources, and trades real USDC within its budget |
| `puls markets` | Live prediction markets + odds |
| `puls feed` | Live trade stream |
| `puls oracle <slug>` | The AI swarm's consensus vs the crowd on a market |
| `puls stats` | Platform traction |
| `puls whoami` | Your wallet + USDC balance |
| `puls login <key>` / `puls logout` | Manage your API key |

`markets`, `feed`, `oracle`, and `stats` are public (no key needed). `chat` and `whoami` use your key.

## Notes

- Point at another backend with `PULS_API=https://… puls …`
- Disable the intro animation with `PULS_NO_ANIM=1`
- The agent must be started once in the app (My Agent → fund & start) before `puls chat` can trade.

Built on Arc · powered by Circle · [docs.pulsmarket.tech](https://docs.pulsmarket.tech)
