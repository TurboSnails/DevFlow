#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/dev-flow/start.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "start.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"
grep -q '\$ARGUMENTS' "$FILE" || fail "does not reference \$ARGUMENTS"
grep -qi 'dev-flow' "$FILE" || fail "does not mention the dev-flow skill"
grep -qi 'Skill tool' "$FILE" || fail "does not instruct using the Skill tool to invoke it"

if grep -qi 'state_init' "$FILE"; then
  fail "must not duplicate state_init logic directly (should delegate to the dev-flow skill instead)"
fi

echo "PASS: commands/dev-flow/start.md structure"
