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
assert_eq "extract_tld bare tld" "com" "$(extract_tld com)"

# validate_tld: curated hit
validate_tld com; assert_eq "validate_tld com (curated)" "0" "$?"
# validate_tld: not in curated, but in IANA cache fixture
validate_tld dev; assert_eq "validate_tld dev (iana)" "0" "$?"
# validate_tld: bogus
validate_tld zzznotreal; assert_eq "validate_tld bogus" "1" "$?"
validate_tld ""; assert_eq "validate_tld empty arg" "1" "$?"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
