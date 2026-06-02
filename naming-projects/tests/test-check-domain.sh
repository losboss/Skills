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
