#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/retro.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "retro.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"

count="$(grep -cE '^[1-3]\. ' "$FILE")"
[ "$count" = "3" ] || fail "expected exactly 3 numbered questions, found $count"

grep -qi 'wait for the user' "$FILE" || fail "does not instruct waiting for user input on each question"

echo "PASS: commands/gs/retro.md structure"
