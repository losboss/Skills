---
name: naming-projects
description: Brainstorm names for a project and propose real, verified-available domain names. Use when the user wants to name a project, app, product, company, library, newsletter, or brand; mentions "name ideas", "what should I call", "naming", "brand name", "domain name", "available domain", "check domain", or "is this domain taken". Generates candidates across four naming styles and verifies domain availability before suggesting.
metadata:
  author: Matthew
  version: 1.0.0
  category: productivity
  tags: [naming, branding, domains, brainstorming, availability]
---

# Naming Projects

Help name a project and propose real, likely-available domains for it. Names are generated
across four styles; domains are verified with `scripts/check-domain.sh` before being shown;
TLDs are validated so suggestions are always real domains.

## Workflow

### 1. Gather context (ask briefly, then proceed)
Ask a few concise questions — one or two messages, not an interrogation:
- What does the project do? (one-liner)
- Who is it for? (audience)
- Tone / vibe? (e.g. playful, serious, technical, premium)
- Any words to include or avoid? Length preference?
- TLD preferences? Default: `.com` first, then short/creative TLDs.

### 2. Generate candidates
Read `references/naming-guidance.md`. Produce a generous pool (~6–10 per style) across all
four styles — real/evocative, coined/invented, compound/mashup, playful/metaphor — each with
a one-line rationale.

### 3. Check domains
For each promising candidate, build domain variants honoring the user's TLD preferences
(`.com` first by default). Run the checker per domain:

```bash
scripts/check-domain.sh lumora.com
```

Output is tab-separated: `domain<TAB>status<TAB>source<TAB>note`, where status is
`available`, `registered`, `unknown`. Keep names with at least one `available` domain.
Never suggest a domain whose status is `registered`. **Never invent TLDs** — the script
rejects unreal TLDs with status `unknown` / source `tld`.

### 4. Present results
Group by naming style. For each kept name: the name, its one-line rationale, and its
available domain option(s) with the source noted. Always end with:
"Likely available — confirm at a registrar before buying."

## Availability providers

`scripts/check-domain.sh` auto-selects the best provider whose credentials are present,
in this order. With none set it uses RDAP + DNS (no setup required).

| Provider   | Env vars                                                              |
|------------|----------------------------------------------------------------------|
| Cloudflare | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`                       |
| Namecheap  | `NAMECHEAP_API_USER`, `NAMECHEAP_API_KEY`, `NAMECHEAP_USERNAME`, `NAMECHEAP_CLIENT_IP` |
| GoDaddy    | `GODADDY_KEY`, `GODADDY_SECRET` (availability needs 50+ domains or ~$20/mo spend) |
| WhoisJSON  | `WHOISJSON_API_KEY`                                                   |
| RDAP       | none (default; authoritative for gTLDs)                              |
| DNS        | none (fallback / cross-check)                                         |

Availability is never a guarantee — always tell the user to confirm at a registrar.

### Cloudflare setup (optional, preferred provider)

Cloudflare is the most authoritative provider. It activates only when **both** env vars are
set; if either is missing, the script falls through to the next provider.

1. **Create an API token** at <https://dash.cloudflare.com/profile/api-tokens> → *Create
   Token* → *Create Custom Token*. Give it an **Account**-scoped permission for domain
   registration (the Registrar API is account-scoped, not zone-scoped). Copy the token value
   (shown only once).
2. **Find your Account ID** in the dashboard URL (`dash.cloudflare.com/<ACCOUNT_ID>/...`) or
   the account overview — a 32-character hex string.
3. **Export both** (add to `~/.zshrc` to persist):
   ```sh
   export CLOUDFLARE_API_TOKEN="your-token-here"
   export CLOUDFLARE_ACCOUNT_ID="your-account-id-here"
   ```
4. **Verify:** `scripts/check-domain.sh google.com` — the 3rd (tab-separated) column shows the
   source. With the token set it reads `cloudflare`; without it, `rdap`. The token is piped to
   `curl` via stdin config, so it never appears in the process list.

If the source column keeps showing `rdap` despite both vars being set, the cause is usually a
token without the right account permission, a wrong Account ID, or missing `jq` (Cloudflare
parsing requires `jq`) — the script falls back to RDAP rather than erroring in all these cases.

The same env-var pattern applies to the other credentialed providers (see the table above):
set their variables and the script auto-selects the highest-priority one available.

## Requirements

- `curl` and `dig` (preinstalled on macOS) — used for RDAP and DNS.
- `jq` is recommended: the Cloudflare provider requires `jq` to parse its response (without
  it, Cloudflare lookups fall back to RDAP). The GoDaddy and WhoisJSON providers parse with
  `jq` if present, otherwise fall back to `python3`.
- Credentials are optional. With none set, the script works out of the box via RDAP + DNS.
  When set, API credentials are passed to `curl` via stdin config so they never appear in the
  process list.
