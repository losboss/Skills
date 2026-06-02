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

# select_provider precedence (unset everything first)
unset CLOUDFLARE_API_TOKEN CLOUDFLARE_ACCOUNT_ID NAMECHEAP_API_USER NAMECHEAP_API_KEY \
      NAMECHEAP_USERNAME NAMECHEAP_CLIENT_IP GODADDY_KEY GODADDY_SECRET WHOISJSON_API_KEY 2>/dev/null || true
assert_eq "provider default rdap" "rdap" "$(select_provider)"
assert_eq "provider whoisjson" "whoisjson" "$(WHOISJSON_API_KEY=x select_provider)"
assert_eq "provider godaddy" "godaddy" "$(GODADDY_KEY=a GODADDY_SECRET=b select_provider)"
assert_eq "provider namecheap" "namecheap" "$(NAMECHEAP_API_USER=u NAMECHEAP_API_KEY=k NAMECHEAP_USERNAME=u NAMECHEAP_CLIENT_IP=1.2.3.4 select_provider)"
assert_eq "provider cloudflare wins" "cloudflare" "$(CLOUDFLARE_API_TOKEN=t CLOUDFLARE_ACCOUNT_ID=a GODADDY_KEY=a GODADDY_SECRET=b select_provider)"

# emit: tab-separated normalized line
assert_eq "emit format" "$(printf 'lumora.com\tavailable\trdap\t')" "$(emit lumora.com available rdap '')"
# reconcile: rdap-available but DNS resolves -> registered
assert_eq "reconcile parked" "registered" "$(reconcile available yes)"
assert_eq "reconcile clean available" "available" "$(reconcile available no)"
assert_eq "reconcile registered passthrough" "registered" "$(reconcile registered no)"
assert_eq "reconcile unknown passthrough" "unknown" "$(reconcile unknown no)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
