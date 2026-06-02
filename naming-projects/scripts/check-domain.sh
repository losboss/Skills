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

main() {
  printf 'not yet implemented\n' >&2
  return 1
}

if [[ -z "${TESTONLY:-}" ]]; then
  main "$@"
fi
