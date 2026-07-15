#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/office-hours.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "office-hours.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"

count="$(grep -cE '^[1-6]\. ' "$FILE")"
[ "$count" = "6" ] || fail "expected exactly 6 numbered questions, found $count"

grep -qi 'one at a time' "$FILE" || fail "does not instruct asking one at a time"

echo "PASS: commands/gs/office-hours.md structure"
