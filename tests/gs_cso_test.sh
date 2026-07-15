#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/cso.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "cso.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"

count="$(grep -cE '^[1-4]\. ' "$FILE")"
[ "$count" = "4" ] || fail "expected exactly 4 checklist items, found $count"

grep -qF 'frozen-paths.txt' "$FILE" || fail "does not cross-reference .claude/frozen-paths.txt"

echo "PASS: commands/gs/cso.md structure"
