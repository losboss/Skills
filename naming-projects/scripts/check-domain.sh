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

# fetch_iana_to_tmp -> writes lowercased IANA TLD list to a temp file, echoes its path
fetch_iana_to_tmp() {
  local tmp; tmp="$(mktemp)" || return 1
  if ( set -o pipefail; curl -fsS --max-time 15 \
        "https://data.iana.org/TLD/tlds-alpha-by-domain.txt" \
        | grep -v '^#' | tr '[:upper:]' '[:lower:]' > "$tmp" ) && [[ -s "$tmp" ]]; then
    printf '%s' "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# validate_tld TLD -> 0 if a real TLD (curated allowlist, then IANA), else 1
validate_tld() {
  [[ -z "${1:-}" ]] && return 1
  local tld; tld="$(lc "$1")"
  if grep -qxF "$tld" "$TLDS_FILE" 2>/dev/null; then
    return 0
  fi
  local cache="${IANA_CACHE:-}" created=""
  if [[ -z "$cache" ]]; then
    cache="$(fetch_iana_to_tmp)" || return 1
    created="$cache"
  fi
  local rc
  grep -qxF "$tld" "$cache"; rc=$?
  [[ -n "$created" ]] && rm -f "$created"
  return $rc
}

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

# rdap_status DOMAIN -> available | registered | unknown
rdap_status() {
  local code
  code="$(curl -sL -o /dev/null -w '%{http_code}' --max-time 10 "https://rdap.org/domain/$1")"
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

# json_get FIELD  (reads JSON on stdin) -> value of top-level FIELD, or empty
json_get() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg f "$1" '.[$f] // empty' 2>/dev/null
  else
    python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    v=d.get(sys.argv[1])
    if isinstance(v,bool):
        print(str(v).lower())
    elif isinstance(v,(str,int,float)):
        print(v)
    else:
        print("")
except Exception:
    pass' "$1"
  fi
}

# check_godaddy DOMAIN -> emits line; falls back to RDAP/DNS on error
check_godaddy() {
  local d="$1" resp avail
  resp="$(printf 'header = "Authorization: sso-key %s:%s"\n' "$GODADDY_KEY" "$GODADDY_SECRET" \
    | curl -s --max-time 10 --config - \
        -H "Accept: application/json" \
        "https://api.godaddy.com/v1/domains/available?domain=$d")"
  avail="$(printf '%s' "$resp" | json_get available)"
  case "$avail" in
    true)  emit "$d" available godaddy "" ;;
    false) emit "$d" registered godaddy "" ;;
    *)     check_rdap_dns "$d" ;;
  esac
}

# check_whoisjson DOMAIN -> emits line; falls back to RDAP/DNS on error
# WhoisJSON returns a JSON object; "registered" is a boolean field.
check_whoisjson() {
  local d="$1" resp registered
  resp="$(printf 'header = "Authorization: TOKEN=%s"\n' "$WHOISJSON_API_KEY" \
    | curl -s --max-time 12 --config - \
        "https://whoisjson.com/api/v1/whois?domain=$d")"
  registered="$(printf '%s' "$resp" | json_get registered)"
  case "$registered" in
    false) emit "$d" available whoisjson "" ;;
    true)  emit "$d" registered whoisjson "" ;;
    *)     check_rdap_dns "$d" ;;
  esac
}

main() {
  printf 'not yet implemented\n' >&2
  return 1
}

if [[ -z "${TESTONLY:-}" ]]; then
  main "$@"
fi
