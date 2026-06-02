# naming-projects Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal Claude Code skill (`naming-projects`) that brainstorms project names across four styles and proposes real, verified-available domains.

**Architecture:** A `SKILL.md` defines the naming workflow Claude follows. A single bash script `scripts/check-domain.sh` verifies one domain's availability through a tiered set of providers (Cloudflare → Namecheap → GoDaddy → WhoisJSON → RDAP → DNS), picking the best signal available from present credentials. Reference files supply a curated real-TLD allowlist and naming guidance. Pure logic (TLD parsing/validation, provider selection, status reconciliation, output formatting) is unit-tested with a sourced bash test harness; network calls get a live RDAP smoke test plus manual verification notes for credentialed providers.

**Tech Stack:** Bash 3.2-compatible shell (macOS `/bin/bash`), `curl`, `dig`, `jq` (only for credentialed JSON providers), `python3` (available fallback), RDAP (`rdap.org`), IANA TLD list.

---

## File Structure

```
~/projects/Skills/naming-projects/
├── SKILL.md                      # frontmatter + naming workflow Claude follows
├── DESIGN.md                     # already committed (the approved spec)
├── PLAN.md                       # this file
├── scripts/
│   └── check-domain.sh           # provider-tiered availability checker (sourceable for tests)
├── tests/
│   ├── test-check-domain.sh      # unit tests for pure logic (offline, deterministic)
│   └── fixtures/
│       ├── tlds.txt              # tiny TLD allowlist fixture
│       └── iana.txt              # tiny IANA-style fixture
└── references/
    ├── tlds.txt                  # curated allowlist of real TLDs (offline baseline)
    └── naming-guidance.md        # the 4 naming styles + pitfalls
```

**Responsibilities:**
- `check-domain.sh` — all availability logic; functions are independently testable; `main` runs only when executed directly (guarded by `TESTONLY`).
- `tests/test-check-domain.sh` — sources the script with `TESTONLY=1` and asserts pure-function behavior using fixtures; no network.
- `references/tlds.txt` — offline source of truth for "is this a real TLD"; IANA fetch backs up misses.
- `references/naming-guidance.md` — style definitions + pitfalls Claude consults while generating.
- `SKILL.md` — the workflow; tells Claude when/how to gather context, generate, validate TLDs, call the script, and present results.

**Bash 3.2 constraints (macOS):** No `${var,,}`/`${var^^}` (use `tr`), no `mapfile`/`readarray`, no associative arrays. Use `[[ ]]`, `case`, and plain indexed loops only.

---

## Task 1: Scaffold script skeleton + test harness (first failing test)

**Files:**
- Create: `scripts/check-domain.sh`
- Create: `tests/test-check-domain.sh`
- Create: `tests/fixtures/tlds.txt`
- Create: `tests/fixtures/iana.txt`

- [ ] **Step 1: Create the test fixtures**

`tests/fixtures/tlds.txt`:
```
com
io
co
```

`tests/fixtures/iana.txt`:
```
com
io
co
dev
app
```

- [ ] **Step 2: Create the script skeleton with the TESTONLY guard**

`scripts/check-domain.sh`:
```bash
#!/usr/bin/env bash
# check-domain.sh — verify availability of a single domain via tiered providers.
# Usage: check-domain.sh DOMAIN
# Sourceable for tests: set TESTONLY=1 before sourcing to skip main.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SELF_DIR/.." && pwd)"
TLDS_FILE="${TLDS_FILE:-$SKILL_ROOT/references/tlds.txt}"

# --- pure helpers ---

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# extract_tld DOMAIN -> last DNS label, lowercased
extract_tld() {
  local d; d="$(lc "$1")"
  printf '%s' "${d##*.}"
}

main() {
  printf 'not yet implemented\n' >&2
  return 1
}

if [[ -z "${TESTONLY:-}" ]]; then
  main "$@"
fi
```

- [ ] **Step 3: Write the failing test harness**

`tests/test-check-domain.sh`:
```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TLDS_FILE="$HERE/fixtures/tlds.txt"
export IANA_CACHE="$HERE/fixtures/iana.txt"
TESTONLY=1 . "$HERE/../scripts/check-domain.sh"

PASS=0; FAIL=0
assert_eq() { # desc expected actual
  if [[ "$2" == "$3" ]]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    printf 'FAIL: %s\n  expected: [%s]\n  actual:   [%s]\n' "$1" "$2" "$3"
  fi
}

# extract_tld
assert_eq "extract_tld lumora.com" "com" "$(extract_tld lumora.com)"
assert_eq "extract_tld UPPER.IO" "io" "$(extract_tld UPPER.IO)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
```

- [ ] **Step 4: Run the test, expect PASS for extract_tld**

Run: `bash tests/test-check-domain.sh`
Expected: `2 passed, 0 failed` (extract_tld already implemented in the skeleton).

- [ ] **Step 5: Make the script executable and commit**

```bash
chmod +x scripts/check-domain.sh tests/test-check-domain.sh
git add scripts/check-domain.sh tests/test-check-domain.sh tests/fixtures/tlds.txt tests/fixtures/iana.txt
git commit -m "feat(naming-projects): scaffold check-domain.sh + test harness"
```

---

## Task 2: TLD validation (curated allowlist + IANA fallback)

**Files:**
- Modify: `scripts/check-domain.sh` (add `validate_tld`, `fetch_iana_to_tmp`)
- Modify: `tests/test-check-domain.sh` (add validation tests)

- [ ] **Step 1: Write failing tests for validate_tld**

Add to `tests/test-check-domain.sh` before the summary block:
```bash
# validate_tld: curated hit
validate_tld com; assert_eq "validate_tld com (curated)" "0" "$?"
# validate_tld: not in curated, but in IANA cache fixture
validate_tld dev; assert_eq "validate_tld dev (iana)" "0" "$?"
# validate_tld: bogus
validate_tld zzznotreal; assert_eq "validate_tld bogus" "1" "$?"
```

- [ ] **Step 2: Run tests, expect failure**

Run: `bash tests/test-check-domain.sh`
Expected: FAIL lines for the three validate_tld asserts (`command not found` / non-zero), summary shows failures.

- [ ] **Step 3: Implement validate_tld + fetch_iana_to_tmp**

In `scripts/check-domain.sh`, add after `extract_tld`:
```bash
# fetch_iana_to_tmp -> writes lowercased IANA TLD list to a temp file, echoes its path
fetch_iana_to_tmp() {
  local tmp; tmp="$(mktemp)" || return 1
  if curl -fsS --max-time 15 "https://data.iana.org/TLD/tlds-alpha-by-domain.txt" \
      | grep -v '^#' | tr '[:upper:]' '[:lower:]' > "$tmp" && [[ -s "$tmp" ]]; then
    printf '%s' "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# validate_tld TLD -> 0 if a real TLD (curated allowlist, then IANA), else 1
validate_tld() {
  local tld; tld="$(lc "$1")"
  if grep -qxF "$tld" "$TLDS_FILE" 2>/dev/null; then
    return 0
  fi
  local cache="${IANA_CACHE:-}"
  if [[ -z "$cache" ]]; then
    cache="$(fetch_iana_to_tmp)" || return 1
  fi
  grep -qxF "$tld" "$cache"
}
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `bash tests/test-check-domain.sh`
Expected: all asserts pass, `5 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/check-domain.sh tests/test-check-domain.sh
git commit -m "feat(naming-projects): validate TLDs against curated list + IANA"
```

---

## Task 3: Provider selection precedence

**Files:**
- Modify: `scripts/check-domain.sh` (add `select_provider`)
- Modify: `tests/test-check-domain.sh` (add precedence tests)

- [ ] **Step 1: Write failing tests for select_provider**

Add to `tests/test-check-domain.sh`:
```bash
# select_provider precedence (unset everything first)
unset CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID NAMECHEAP_API_USER NAMECHEAP_API_KEY \
      NAMECHEAP_USERNAME NAMECHEAP_CLIENT_IP GODADDY_KEY GODADDY_SECRET WHOISJSON_API_KEY 2>/dev/null || true
assert_eq "provider default rdap" "rdap" "$(select_provider)"
WHOISJSON_API_KEY=x assert_eq "provider whoisjson" "whoisjson" "$(WHOISJSON_API_KEY=x select_provider)"
assert_eq "provider godaddy" "godaddy" "$(GODADDY_KEY=a GODADDY_SECRET=b select_provider)"
assert_eq "provider namecheap" "namecheap" "$(NAMECHEAP_API_USER=u NAMECHEAP_API_KEY=k NAMECHEAP_USERNAME=u NAMECHEAP_CLIENT_IP=1.2.3.4 select_provider)"
assert_eq "provider cloudflare wins" "cloudflare" "$(CLOUDFLARE_API_TOKEN=t CLOUDFLARE_ACCOUNT_ID=a GODADDY_KEY=a GODADDY_SECRET=b select_provider)"
```

- [ ] **Step 2: Run tests, expect failure**

Run: `bash tests/test-check-domain.sh`
Expected: FAIL on the select_provider asserts (`command not found`).

- [ ] **Step 3: Implement select_provider**

Add to `scripts/check-domain.sh`:
```bash
# select_provider -> name of the best provider whose credentials are present
select_provider() {
  if [[ -n "${CLOUDFLARE_API_TOKEN:-}" && -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    printf 'cloudflare'
  elif [[ -n "${NAMECHEAP_API_USER:-}" && -n "${NAMECHEAP_API_KEY:-}" \
          && -n "${NAMECHEAP_USERNAME:-}" && -n "${NAMECHEAP_CLIENT_IP:-}" ]]; then
    printf 'namecheap'
  elif [[ -n "${GODADDY_KEY:-}" && -n "${GODADDY_SECRET:-}" ]]; then
    printf 'godaddy'
  elif [[ -n "${WHOISJSON_API_KEY:-}" ]]; then
    printf 'whoisjson'
  else
    printf 'rdap'
  fi
}
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `bash tests/test-check-domain.sh`
Expected: `10 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/check-domain.sh tests/test-check-domain.sh
git commit -m "feat(naming-projects): provider selection precedence"
```

---

## Task 4: Output formatting + RDAP/DNS reconciliation (pure)

**Files:**
- Modify: `scripts/check-domain.sh` (add `emit`, `reconcile`)
- Modify: `tests/test-check-domain.sh` (add tests)

- [ ] **Step 1: Write failing tests**

Add to `tests/test-check-domain.sh`:
```bash
# emit: tab-separated normalized line
assert_eq "emit format" "lumora.com	available	rdap	" "$(emit lumora.com available rdap '')"
# reconcile: rdap-available but DNS resolves -> registered
assert_eq "reconcile parked" "registered" "$(reconcile available yes)"
assert_eq "reconcile clean available" "available" "$(reconcile available no)"
assert_eq "reconcile registered passthrough" "registered" "$(reconcile registered no)"
assert_eq "reconcile unknown passthrough" "unknown" "$(reconcile unknown no)"
```

- [ ] **Step 2: Run tests, expect failure**

Run: `bash tests/test-check-domain.sh`
Expected: FAIL on emit/reconcile asserts.

- [ ] **Step 3: Implement emit + reconcile**

Add to `scripts/check-domain.sh`:
```bash
# emit DOMAIN STATUS SOURCE NOTE -> one tab-separated line
emit() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
}

# reconcile RDAP_STATUS DNS_RESOLVES(yes|no) -> final status
# An RDAP 404 ("available") for a name that resolves in DNS is treated as registered
# (parked/reserved names can 404 in RDAP).
reconcile() {
  if [[ "$1" == "available" && "$2" == "yes" ]]; then
    printf 'registered'
  else
    printf '%s' "$1"
  fi
}
```

- [ ] **Step 4: Run tests, expect PASS**

Run: `bash tests/test-check-domain.sh`
Expected: `15 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/check-domain.sh tests/test-check-domain.sh
git commit -m "feat(naming-projects): output formatting + RDAP/DNS reconciliation"
```

---

## Task 5: RDAP + DNS checkers and the default path

**Files:**
- Modify: `scripts/check-domain.sh` (add `rdap_status`, `dns_resolves`, `check_rdap_dns`)
- Modify: `tests/test-check-domain.sh` (add a live smoke test, skippable offline)

- [ ] **Step 1: Implement the network primitives**

Add to `scripts/check-domain.sh`:
```bash
# rdap_status DOMAIN -> available | registered | unknown
rdap_status() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://rdap.org/domain/$1")"
  case "$code" in
    404) printf 'available' ;;
    200) printf 'registered' ;;
    *)   printf 'unknown' ;;
  esac
}

# dns_resolves DOMAIN -> yes | no  (has NS or A records)
dns_resolves() {
  local ns a
  ns="$(dig +short NS "$1" 2>/dev/null)"
  a="$(dig +short A "$1" 2>/dev/null)"
  if [[ -n "$ns" || -n "$a" ]]; then printf 'yes'; else printf 'no'; fi
}

# check_rdap_dns DOMAIN -> emits a normalized line using RDAP, with DNS cross-check/fallback
check_rdap_dns() {
  local d="$1" r dns final
  r="$(rdap_status "$d")"
  if [[ "$r" == "unknown" ]]; then
    # RDAP doesn't cover this TLD (or errored) -> fall back to a DNS hint only
    if [[ "$(dns_resolves "$d")" == "yes" ]]; then
      emit "$d" registered dns "resolves in DNS"
    else
      emit "$d" available dns "no DNS records (hint only — confirm at a registrar)"
    fi
    return 0
  fi
  dns="$(dns_resolves "$d")"
  final="$(reconcile "$r" "$dns")"
  if [[ "$final" == "registered" && "$r" == "available" ]]; then
    emit "$d" registered rdap+dns "RDAP 404 but resolves in DNS (parked/reserved)"
  else
    emit "$d" "$final" rdap ""
  fi
}
```

- [ ] **Step 2: Add a live smoke test (skips cleanly when offline)**

Add to `tests/test-check-domain.sh` before the summary:
```bash
# Live RDAP smoke test — skip if no network
if curl -s -o /dev/null --max-time 5 https://rdap.org/ ; then
  assert_eq "rdap google.com registered" "registered" "$(rdap_status google.com)"
  line="$(check_rdap_dns google.com)"
  assert_eq "check_rdap_dns google status" "registered" "$(printf '%s' "$line" | cut -f2)"
else
  printf 'SKIP: live RDAP smoke test (no network)\n'
fi
```

- [ ] **Step 3: Run tests, expect PASS (or SKIP offline)**

Run: `bash tests/test-check-domain.sh`
Expected: previous asserts still pass; with network, two more pass; offline shows `SKIP`.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-domain.sh tests/test-check-domain.sh
git commit -m "feat(naming-projects): RDAP + DNS default availability path"
```

---

## Task 6: Credentialed JSON providers — GoDaddy + WhoisJSON

**Files:**
- Modify: `scripts/check-domain.sh` (add `json_get`, `check_godaddy`, `check_whoisjson`)

**Note:** These require credentials; they are verified manually (Step 4). All fall back to `check_rdap_dns` on any error/unknown so the script never hard-fails.

- [ ] **Step 1: Add a JSON field helper (jq, python3 fallback)**

Add to `scripts/check-domain.sh`:
```bash
# json_get FIELD  (reads JSON on stdin) -> value of top-level FIELD, or empty
json_get() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg f "$1" '.[$f] // empty' 2>/dev/null
  else
    python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    v=d.get(sys.argv[1],"")
    print("" if v is None else (str(v).lower() if isinstance(v,bool) else v))
except Exception:
    pass' "$1"
  fi
}
```

- [ ] **Step 2: Implement check_godaddy**

Add to `scripts/check-domain.sh`:
```bash
# check_godaddy DOMAIN -> emits line; falls back to RDAP/DNS on error
check_godaddy() {
  local d="$1" resp avail
  resp="$(curl -s --max-time 10 \
    -H "Authorization: sso-key ${GODADDY_KEY}:${GODADDY_SECRET}" \
    -H "Accept: application/json" \
    "https://api.godaddy.com/v1/domains/available?domain=$d")"
  avail="$(printf '%s' "$resp" | json_get available)"
  case "$avail" in
    true)  emit "$d" available godaddy "" ;;
    false) emit "$d" registered godaddy "" ;;
    *)     check_rdap_dns "$d" ;;
  esac
}
```

- [ ] **Step 3: Implement check_whoisjson**

Add to `scripts/check-domain.sh`:
```bash
# check_whoisjson DOMAIN -> emits line; falls back to RDAP/DNS on error
# WhoisJSON returns a JSON object; an unregistered domain has no "registered"/"created" data.
check_whoisjson() {
  local d="$1" resp registered
  resp="$(curl -s --max-time 12 \
    -H "Authorization: Token=${WHOISJSON_API_KEY}" \
    "https://whoisjson.com/api/v1/whois?domain=$d")"
  # "registered" is a boolean field in the WhoisJSON response
  registered="$(printf '%s' "$resp" | json_get registered)"
  case "$registered" in
    false) emit "$d" available whoisjson "" ;;
    true)  emit "$d" registered whoisjson "" ;;
    *)     check_rdap_dns "$d" ;;
  esac
}
```

- [ ] **Step 4: Verify the two endpoints against live docs, adjust field names if needed**

Confirm the request/response shapes are current (field names especially), since both APIs evolve:
- GoDaddy availability: `https://developer.godaddy.com/doc/endpoint/domains` — confirm `GET /v1/domains/available?domain=` returns `{"available": <bool>, ...}`.
- WhoisJSON: `https://whoisjson.com/documentation` — confirm the whois endpoint path, the `Authorization: Token=` header, and the boolean field indicating registration (`registered`). If the field differs, update `json_get registered` in `check_whoisjson` accordingly.

Use WebFetch on each doc URL. If a field name differs, edit the function and note it in the commit.

- [ ] **Step 5: Commit**

```bash
git add scripts/check-domain.sh
git commit -m "feat(naming-projects): GoDaddy + WhoisJSON availability providers"
```

---

## Task 7: Credentialed providers — Namecheap (XML) + Cloudflare

**Files:**
- Modify: `scripts/check-domain.sh` (add `check_namecheap`, `check_cloudflare`)

- [ ] **Step 1: Implement check_namecheap (XML response)**

Namecheap's `domains.check` returns `<DomainCheckResult Domain="..." Available="true" .../>`.
Reuse the same env vars as the existing `namecheap-domains` skill. Add to `scripts/check-domain.sh`:
```bash
# check_namecheap DOMAIN -> emits line; falls back to RDAP/DNS on error
check_namecheap() {
  local d="$1" resp avail
  resp="$(curl -s --max-time 12 -G "https://api.namecheap.com/xml.response" \
    --data-urlencode "ApiUser=${NAMECHEAP_API_USER}" \
    --data-urlencode "ApiKey=${NAMECHEAP_API_KEY}" \
    --data-urlencode "UserName=${NAMECHEAP_USERNAME}" \
    --data-urlencode "ClientIp=${NAMECHEAP_CLIENT_IP}" \
    --data-urlencode "Command=namecheap.domains.check" \
    --data-urlencode "DomainList=$d")"
  # Extract Available="true|false" from the DomainCheckResult element
  avail="$(printf '%s' "$resp" \
    | grep -o 'Available="[a-zA-Z]*"' | head -1 \
    | sed 's/.*"\(.*\)"/\1/' | tr '[:upper:]' '[:lower:]')"
  case "$avail" in
    true)  emit "$d" available namecheap "" ;;
    false) emit "$d" registered namecheap "" ;;
    *)     check_rdap_dns "$d" ;;
  esac
}
```

- [ ] **Step 2: Implement check_cloudflare**

Cloudflare's Registrar API (beta, 2026) exposes a domain availability "check". Add to `scripts/check-domain.sh`:
```bash
# check_cloudflare DOMAIN -> emits line; falls back to RDAP/DNS on error
check_cloudflare() {
  local d="$1" resp avail
  resp="$(curl -s --max-time 10 \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/registrar/domains/${d}/check")"
  # Expected: {"success":true,"result":{"available":<bool>,...}}
  avail="$(printf '%s' "$resp" | jq -r '.result.available // empty' 2>/dev/null)"
  case "$avail" in
    true)  emit "$d" available cloudflare "" ;;
    false) emit "$d" registered cloudflare "" ;;
    *)     check_rdap_dns "$d" ;;
  esac
}
```

- [ ] **Step 3: Verify both endpoints against live docs and adjust**

- Namecheap: cross-check the call against `namecheap-domains/references/api-domains.md` (the `domains.check` section). Confirm parameter names and the `Available="..."` attribute. (Sandbox base URL `https://api.sandbox.namecheap.com/xml.response` is available for testing.)
- Cloudflare: confirm the exact path/shape for the Registrar **check** endpoint via WebFetch on `https://developers.cloudflare.com/api/resources/registrar/methods/check` and `https://developers.cloudflare.com/registrar/registrar-api/`. The beta path or JSON field (`.result.available`) may differ — update the URL and the `jq` filter in `check_cloudflare` to match the documented response. This is the one endpoint most likely to need adjustment; treat the code above as the starting shape, not gospel.

- [ ] **Step 4: Commit**

```bash
git add scripts/check-domain.sh
git commit -m "feat(naming-projects): Namecheap + Cloudflare availability providers"
```

---

## Task 8: Wire up main() + dispatch + curated TLD list

**Files:**
- Modify: `scripts/check-domain.sh` (replace stub `main`)
- Create: `references/tlds.txt`

- [ ] **Step 1: Create the curated TLD allowlist**

`references/tlds.txt` (one lowercase TLD per line, no dots):
```
com
net
org
io
co
app
dev
ai
xyz
so
sh
me
gg
tech
design
studio
work
fm
gl
to
cc
tv
ws
inc
llc
page
site
online
store
shop
blog
wiki
email
chat
live
life
world
space
fun
cool
run
build
tools
```

- [ ] **Step 2: Replace the stub main with real dispatch**

In `scripts/check-domain.sh`, replace the `main()` stub with:
```bash
main() {
  if [[ $# -lt 1 || -z "${1:-}" ]]; then
    printf 'usage: check-domain.sh DOMAIN\n' >&2
    return 2
  fi
  local domain tld provider
  domain="$(lc "$1")"
  tld="$(extract_tld "$domain")"

  if ! validate_tld "$tld"; then
    emit "$domain" unknown tld "unrecognized TLD '$tld' — not a real TLD"
    return 0
  fi

  provider="$(select_provider)"
  case "$provider" in
    cloudflare) check_cloudflare "$domain" ;;
    namecheap)  check_namecheap  "$domain" ;;
    godaddy)    check_godaddy    "$domain" ;;
    whoisjson)  check_whoisjson  "$domain" ;;
    rdap|*)     check_rdap_dns   "$domain" ;;
  esac
}
```

- [ ] **Step 3: Integration smoke — real run against the live default path**

Run (with no provider creds set, so it uses RDAP):
```bash
./scripts/check-domain.sh google.com
./scripts/check-domain.sh thisbranddoesnotexist20260602xyz.com
./scripts/check-domain.sh foo.zzznotreal
```
Expected (tab-separated; status in column 2):
- `google.com` → `registered` (source `rdap`)
- the random `.com` → `available` (source `rdap`)
- `foo.zzznotreal` → `unknown` (source `tld`, note about unrecognized TLD)

- [ ] **Step 4: Run the full unit suite once more**

Run: `bash tests/test-check-domain.sh`
Expected: all asserts pass (`15 passed, 0 failed`, plus live smoke if online).

- [ ] **Step 5: Commit**

```bash
git add scripts/check-domain.sh references/tlds.txt
git commit -m "feat(naming-projects): wire main() dispatch + curated TLD allowlist"
```

---

## Task 9: Naming guidance reference

**Files:**
- Create: `references/naming-guidance.md`

- [ ] **Step 1: Write the guidance file**

`references/naming-guidance.md`:
```markdown
# Naming Guidance

Generate a generous pool of candidates (aim for ~6–10 per style) so there's room to
filter by domain availability. Give each candidate a one-line rationale.

## The four styles

### 1. Real / evocative words
Actual dictionary or near-dictionary words that evoke the project's feeling.
Examples: Compass, Drift, Lumen, Anchor, Ember.
Strength: instantly meaningful. Weakness: exact-match domains are usually taken.

### 2. Coined / invented
Made-up, brandable words — often vowel-rich and easy to say.
Examples: Lumora, Zentry, Qovo, Nuvio, Selka.
Strength: best domain availability, trademarkable. Weakness: no built-in meaning.

### 3. Compound / mashup
Two words fused or blended.
Examples: Notewell, Flowstate, Mailgun, Snaplet, Workbench.
Strength: descriptive yet ownable. Weakness: can get long.

### 4. Playful / metaphor
Puns, metaphors, and unexpected angles tied to what the project does.
Examples: Octopus (multitasking), Honeycomb (observability), Beacon, Otter.
Strength: memorable and warm. Weakness: can be opaque without context.

## Pitfalls to screen for

- **Hard to spell or say** — if you'd need to spell it aloud, drop it.
- **Awkward in code / URLs** — hyphens, doubled letters, digits-as-words.
- **Trademark collision risk** — obvious clashes with well-known brands (lightweight
  heuristic only; tell the user to do a real trademark search).
- **Negative or unintended meaning** — especially in other major languages.
- **Pluralization / "the" traps** — name already plural, or only works with "the".

## Presenting results

Group suggestions by style. For each kept name, show: the name, a one-line rationale,
and its verified domain options with status. Always end with:
"Likely available — confirm at a registrar before buying."
```

- [ ] **Step 2: Commit**

```bash
git add references/naming-guidance.md
git commit -m "docs(naming-projects): add naming guidance reference"
```

---

## Task 10: SKILL.md (the workflow)

**Files:**
- Create: `SKILL.md`

- [ ] **Step 1: Write SKILL.md with repo-matching frontmatter**

`SKILL.md`:
```markdown
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
```

- [ ] **Step 2: Sanity-check the script path referenced in SKILL.md**

Run from the skill root: `ls scripts/check-domain.sh references/tlds.txt references/naming-guidance.md`
Expected: all three paths exist.

- [ ] **Step 3: Commit**

```bash
git add SKILL.md
git commit -m "feat(naming-projects): add SKILL.md workflow"
```

---

## Task 11: README table + final verification

**Files:**
- Modify: `README.md` (add the `naming-projects` row)

- [ ] **Step 1: Add the skill to the README table**

In `README.md`, add this row to the skill table (after the `namecheap-domains` row):
```markdown
| [naming-projects](./naming-projects/) | Brainstorm project names across four styles and propose real, verified-available domains (Cloudflare/Namecheap/GoDaddy/WhoisJSON/RDAP) |
```

- [ ] **Step 2: Final full verification**

Run:
```bash
bash tests/test-check-domain.sh
./scripts/check-domain.sh google.com
./scripts/check-domain.sh foo.zzznotreal
```
Expected: unit suite passes; `google.com` → `registered`; `foo.zzznotreal` → `unknown` (unrecognized TLD).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add naming-projects to skills README"
```

---

## Self-Review Notes (for the author)

- **Spec coverage:** four styles (Task 9 + SKILL.md), TLD validation curated+IANA (Task 2), provider tiering Cloudflare→Namecheap→GoDaddy→WhoisJSON→RDAP→DNS (Tasks 3,5,6,7,8), RDAP/DNS cross-check (Tasks 4,5), "never invent TLDs" (Tasks 2,8), "confirm at registrar" disclaimer (Tasks 9,10), README update (Task 11), repo SKILL.md/references conventions (Task 10). All present.
- **Type/name consistency:** function names (`lc`, `extract_tld`, `validate_tld`, `fetch_iana_to_tmp`, `select_provider`, `emit`, `reconcile`, `rdap_status`, `dns_resolves`, `check_rdap_dns`, `json_get`, `check_godaddy`, `check_whoisjson`, `check_namecheap`, `check_cloudflare`, `main`) are used consistently across tasks. Status vocabulary fixed to `available|registered|unknown`. Output is always 4 tab-separated fields.
- **Known risk:** Cloudflare beta + WhoisJSON endpoint shapes are verified live in Tasks 6–7; code falls back to RDAP/DNS on any unexpected response, so a wrong field name degrades gracefully rather than breaking.
```
