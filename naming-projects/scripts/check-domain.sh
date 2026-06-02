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
