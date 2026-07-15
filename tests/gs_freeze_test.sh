#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/freeze.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "freeze.md does not exist"

SNIPPET="$(sed -n '/^```bash$/,/^```$/p' "$FILE" | sed '1d;$d')"
[ -n "$SNIPPET" ] || fail "no fenced bash snippet found in freeze.md"

TMPDIR_TEST="$(mktemp -d)"
export ARGUMENTS="lib/core/payment"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

output="$(cd "$TMPDIR_TEST" && eval "$SNIPPET")"
echo "$output" | grep -q "Frozen: lib/core/payment" || fail "expected 'Frozen: lib/core/payment' on first freeze"
[ -f "$TMPDIR_TEST/.claude/frozen-paths.txt" ] || fail "expected .claude/frozen-paths.txt to be created"
[ "$(wc -l < "$TMPDIR_TEST/.claude/frozen-paths.txt" | tr -d ' ')" = "1" ] || fail "expected exactly one line after first freeze"

# Freezing the same path again reports already-frozen, does not duplicate the line
output="$(cd "$TMPDIR_TEST" && eval "$SNIPPET")"
echo "$output" | grep -q "Already frozen: lib/core/payment" || fail "expected 'Already frozen' on second freeze of same path"
[ "$(wc -l < "$TMPDIR_TEST/.claude/frozen-paths.txt" | tr -d ' ')" = "1" ] || fail "expected still exactly one line, no duplicate"

echo "PASS: commands/gs/freeze.md behavior"
