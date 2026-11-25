#!/usr/bin/env bash
# Contract test, run inside the built image by sdlc's `contract` check: the
# tools are installed and the classifier and findings verbs give the known
# answers for the fixture. Was container.yml's contract-test.
set -euo pipefail

command -v grype >/dev/null
test -x /usr/local/bin/cve-scan
test -x /usr/local/bin/cve-classify
test -f /etc/grype/fleet-images.conf

out=$(cve-classify < tests/fixtures/sample-grype.json)
echo "$out"
grep -q 'total=8' <<<"$out"
grep -q 'fix_crit=2' <<<"$out"
grep -q 'rce=2' <<<"$out"

f=$(cve-findings < tests/fixtures/sample-grype.json)
grep -q 'pkg=node type=binary' <<<"$f"
