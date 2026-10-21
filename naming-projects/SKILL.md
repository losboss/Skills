---
name: naming-projects
description: Brainstorm names for a project, propose real, verified-available domain names, and screen the shortlist against the trademark registers before anyone buys a domain. Use when the user wants to name a project, app, product, company, library, newsletter, or brand; mentions "name ideas", "what should I call", "naming", "brand name", "domain name", "available domain", "check domain", or "is this domain taken", "trademark search", "is this name trademarked". Generates candidates across four naming styles, verifies domain availability and checks the trademark registers before suggesting.
metadata:
  author: Matthew
  version: 1.1.0
  category: productivity
  tags: [naming, branding, domains, brainstorming, availability, trademarks]
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

### 4. Check trademarks (before anyone buys a domain)
A domain can be free while the name is unusable. Screen every name you are about to present
against the trademark register of each country the project will trade in. Canada and the US
by default; ask if it is unclear. Do this **before** step 5, so a name is never chosen, and a
domain never bought, on the strength of an available domain alone.

- **Canada: CIPO's Canadian Trademarks Database**, <https://ised-isde.canada.ca/cipo/trademark-search/srch>.
  It is a JavaScript app, so use a browser (Playwright or Chrome). Set the field to **Trademark**,
  then search the exact word, its singular or plural, and a stem with a wildcard (`sundr*`).
  The search matches whole words, so the wildcard is what catches compounds and near spellings.
  Open any live record that is close and read its owner, classes, goods and services, and status.
- **US: USPTO Trademark Search**, <https://tmsearch.uspto.gov/>. Search the same way.
- **Which classes matter.** Look first at the Nice classes the project will use: 35 for retail,
  marketplaces and business services, 42 for software and SaaS, 9 for downloadable software,
  and 39 for delivery. Then look at any class that matches what is sold.
- **Official marks (Canada, section 9 "Prohibited Mark; Official Mark").** These belong to public
  authorities and block any mark that closely resembles them **in every class**, not just one.
  Flag every one that contains the word, whoever owns it.
- **Descriptive names.** An ordinary word for what the business sells (for example "Sundries" for
  a store of everyday goods) may be refused as clearly descriptive, even with no conflicting mark.
  Say so beside the name.
- **Report per name:** Clear, Close mark (name the mark, number, classes and status), or
  Descriptive risk. Live marks matter. Abandoned or expunged ones only matter as history.

This is a screen, not clearance. For the name that is actually chosen, recommend a trademark
agent's search and opinion before launch.

### 5. Present results
Group by naming style. For each kept name: the name, its one-line rationale, its
available domain option(s) with the source noted, and its trademark screen result. Always end with:
"Likely available — confirm at a registrar before buying. The trademark screen is not
clearance; get an agent's opinion on the name you choose."

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
