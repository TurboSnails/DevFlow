#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/ship.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "ship.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"
grep -q 'git push' "$FILE" || fail "does not mention git push"
grep -q 'gh pr create' "$FILE" || fail "does not mention gh pr create"
grep -qi 'CI' "$FILE" || fail "does not mention waiting for CI"

if grep -q 'gh pr merge' "$FILE"; then
  fail "must not instruct running gh pr merge - merging is out of scope for this command"
fi

grep -qi 'manual' "$FILE" || fail "does not document that merging is a separate manual step"

echo "PASS: commands/gs/ship.md structure"
