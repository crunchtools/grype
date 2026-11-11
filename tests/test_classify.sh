#!/usr/bin/env bash
# Unit tests for cve-classify. Runs the REAL classifier (not a copy of its jq)
# against a hand-built fixture whose counts are known, plus the error path.
#
# Run: tests/test_classify.sh   (needs bash + jq; no grype, no network)

set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
CLASSIFY="$root/rootfs/usr/local/bin/cve-classify"
FIXTURE="$here/fixtures/sample-grype.json"

fail=0
check() {  # check <label> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "ok   - $1 ($3)"
    else
        echo "FAIL - $1: expected '$2', got '$3'"; fail=1
    fi
}

line=$("$CLASSIFY" < "$FIXTURE")
get() { sed -nE "s/.*(^| )$1=([^ ]+).*/\2/p" <<<"$line"; }

echo "# classifier against sample-grype.json"
check "result"   "ok" "$(get result)"
check "total"    "8"  "$(get total)"     # 8 matches
check "crit"     "3"  "$(get crit)"      # 0001,0002,0003
check "high"     "2"  "$(get high)"      # 0004,0005
check "med"      "1"  "$(get med)"       # 0006
check "fix_crit" "2"  "$(get fix_crit)"  # 0001,0002 (fixed criticals) — the PAGE tier
check "fix_high" "1"  "$(get fix_high)"  # 0004
check "unfix"    "3"  "$(get unfix)"     # 0003 not-fixed, 0005 not-fixed, 0007 wont-fix
check "rce"      "2"  "$(get rce)"       # 0001 (AV:N) + 0002 (no vector => network)

echo "# error path"
bad_line=$(printf 'not json at all' | "$CLASSIFY")
check "invalid_json result" "error" "$(sed -nE 's/.*(^| )result=([^ ]+).*/\2/p' <<<"$bad_line")"

echo "# empty matches"
empty_line=$(printf '{"matches":[]}' | "$CLASSIFY")
check "empty total" "0" "$(sed -nE 's/.*(^| )total=([^ ]+).*/\2/p' <<<"$empty_line")"

# --- cve-findings: the per-fixable-Critical bump detail -----------------------
FINDINGS="$root/rootfs/usr/local/bin/cve-findings"
echo "# cve-findings against sample-grype.json (2 fixable criticals: a deb and an embedded binary)"
findings=$("$FINDINGS" < "$FIXTURE")
check "findings line count"        "2" "$(grep -c . <<<"$findings")"
check "deb finding (libtest)"      "cve=CVE-TEST-0001 pkg=libtest type=deb installed=1.0.0 fix=1.2.3 net=1 path=/var/lib/dpkg/status" "$(grep 'pkg=libtest' <<<"$findings")"
check "embedded-binary (node)"     "cve=CVE-TEST-0002 pkg=node type=binary installed=25.2.1 fix=2.0.0 net=1 path=/usr/local/bin/node" "$(grep 'pkg=node' <<<"$findings")"
check "findings empty on clean"    "" "$(printf '{"matches":[]}' | "$FINDINGS")"
check "findings skip non-fixable"  "0" "$(printf '{"matches":[{"vulnerability":{"id":"X","severity":"Critical","fix":{"state":"not-fixed"}},"artifact":{"name":"p"}}]}' | "$FINDINGS" | grep -c .)"

if [ "$fail" -eq 0 ]; then echo "PASS"; else echo "SOME TESTS FAILED"; fi
exit "$fail"
