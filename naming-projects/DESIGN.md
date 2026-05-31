# Design: `naming-projects` Skill

**Date:** 2026-05-31
**Status:** Approved (design)
**Author:** Matthew (with Claude)
**Location:** `~/projects/Skills/naming-projects/` (this skills repo)

## Purpose

A skill that helps name projects — software/SaaS, businesses/brands, open-source libraries,
and content/creative work — and proposes **real, likely-available domain names** for the
chosen direction. Domain availability is actually verified (not guessed), and TLDs are
validated against real lists so Claude never invents domains.

## Location & conventions

Lives in this repo following its existing skill conventions (see `namecheap-domains/`):

```
~/projects/Skills/naming-projects/
├── SKILL.md                      # YAML frontmatter + the workflow Claude follows
├── scripts/
│   └── check-domain.sh           # provider-tiered availability checker
└── references/
    ├── tlds.txt                  # curated allowlist of real TLDs (offline baseline)
    └── naming-guidance.md        # the 4 naming styles + pitfalls
```

Also update the repo `README.md` skill table with a `naming-projects` row.
Authored to match this repo's existing skill structure (frontmatter + `SKILL.md` + `references/`).

## Workflow (what the skill instructs Claude to do)

1. **Gather context** — ask a few concise questions before generating:
   - What the project does (one-liner)
   - Audience / who it's for
   - Tone / vibe (e.g. playful, serious, technical, premium)
   - Words to include or avoid
   - Name length preference
   - TLD preferences — default: `.com` first, then short/creative TLDs
2. **Generate candidates** — produce a generous pool across all four naming styles, each
   with a one-line rationale. Styles:
   - Real / evocative words (e.g. Compass, Drift, Lumen)
   - Coined / invented (e.g. Lumora, Zentry, Qovo)
   - Compound / mashup (e.g. Notewell, Flowstate)
   - Playful / metaphor (e.g. Octopus, Honeycomb)
3. **Validate TLDs** — every proposed domain's TLD must appear in `references/tlds.txt`.
   Unknown TLDs are validated against the live IANA list
   (`https://data.iana.org/TLD/tlds-alpha-by-domain.txt`) before use. **Never invent TLDs.**
4. **Check availability** — run `scripts/check-domain.sh` per candidate domain; filter the
   batch down to names that are likely available.
5. **Present the batch** — grouped by naming style. For each name: the name, a one-line
   rationale, and its verified domain options with status. Always include the disclaimer:
   *"Likely available — confirm at a registrar before buying."*

## Domain availability checker — `check-domain.sh`

**Usage:** `check-domain.sh DOMAIN` (e.g. `check-domain.sh lumora.com`)

**TLD validation first:** reject/flag any domain whose TLD is not in `references/tlds.txt`
(or, on miss, not in the freshly-fetched IANA list).

**Provider tiering — best signal first, based on which credentials are present:**

| Order | Provider   | Trigger (env var)                  | Notes |
|-------|------------|------------------------------------|-------|
| 1     | Cloudflare | `CLOUDFLARE_API_TOKEN`             | Registrar API `check` endpoint — authoritative availability + pricing (beta, 2026). Preferred. |
| 2     | Namecheap  | `NAMECHEAP_API_USER` + `NAMECHEAP_API_KEY` (+ client IP allowlist) | `namecheap.domains.check` — already wired in this repo via the `namecheap-domains` skill. Reuse those creds. |
| 3     | GoDaddy    | `GODADDY_KEY` + `GODADDY_SECRET`   | `/v1/domains/available` — authoritative, but account needs 50+ domains or ~$20/mo spend for availability access. |
| 4     | WhoisJSON  | `WHOISJSON_API_KEY`                | 1,000 free calls/mo, 1,500+ TLDs, normalizes RDAP+WHOIS. |
| 5     | RDAP       | _(none — default)_                 | `https://rdap.org/domain/NAME`: HTTP `404` = available, `200` = registered. Authoritative for gTLDs (WHOIS sunset Jan 2025). |
| 6     | DNS        | _(none — fallback/cross-check)_    | `dig +short NS NAME`: nameservers present = registered; empty = likely-available hint. Used when RDAP doesn't cover the TLD, and as a cross-check. |

**Cross-check rule:** if RDAP reports a domain as available but DNS shows it resolves
(A/NS records exist), downgrade to **registered** — a reserved/parked name can 404 in RDAP.

**Normalized output (per domain):**

```
domain   · status (available | registered | unknown) · source (cloudflare|namecheap|godaddy|whoisjson|rdap|dns) · note
```

Status is never presented as a guarantee — the skill always tells the user to confirm at a
registrar before purchasing.

## References

- `references/tlds.txt` — curated, hand-picked list of common real TLDs that works offline
  (`.com .net .org .io .app .dev .ai .co .xyz .so .sh .me .gg` and other well-known ones).
  The IANA fetch backs this up for anything not on the curated list.
- `references/naming-guidance.md` — short guidance on each of the four styles plus common
  naming pitfalls (hard-to-spell, awkward in code, trademark-collision risk, negative
  connotations in other languages).

## Out of scope (YAGNI)

- Actually registering/purchasing domains (the `namecheap-domains` skill handles registration)
- Trademark/legal clearance (only a lightweight heuristic caution)
- Logo / visual branding
- Persisting naming history between sessions

## Key decisions

- **Cloudflare replaces Domainr** as the preferred authoritative provider — Domainr was
  deprecated after its 2023 Fastly acquisition; Cloudflare's 2026 Registrar API is current,
  authoritative, and agent-designed.
- **Namecheap added** as a provider tier — creds already exist in this repo; zero extra setup.
- **RDAP over WHOIS** — WHOIS for gTLDs was sunset by ICANN in Jan 2025; RDAP is now the
  authoritative free, no-auth source.
- **Zero-setup baseline** — RDAP + DNS work with no API keys; the paid/authoritative
  providers are purely additive when their credentials are present.
- **Never invent TLDs** — curated allowlist + IANA validation guarantees real domains only.
- **Committed to this repo**, following the existing skill layout, with the README table updated.
