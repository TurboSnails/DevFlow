#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/dev-flow/stop.md"
STATE_LIB="$SCRIPT_DIR/../lib/state.sh"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "stop.md does not exist"

# Extract the single ```bash ... ``` fenced snippet
SNIPPET="$(sed -n '/^```bash$/,/^```$/p' "$FILE" | sed '1d;$d')"
[ -n "$SNIPPET" ] || fail "no fenced bash snippet found in stop.md"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Case 1: active cycle exists ---
source "$STATE_LIB"
state_init "add-user-auth" "openspec"
state_set_phase "build"

output="$(cd "$SCRIPT_DIR/.." && eval "$SNIPPET")"
echo "$output" | grep -q "add-user-auth" || fail "stop output does not mention the feature name"
echo "$output" | grep -q "build" || fail "stop output does not mention the phase reached"
[ -f "$DEV_FLOW_STATE_FILE" ] && fail "state file should be deleted after stop"

# --- Case 2: no active cycle ---
rm -f "$DEV_FLOW_STATE_FILE"
output="$(cd "$SCRIPT_DIR/.." && eval "$SNIPPET")"
echo "$output" | grep -qi "no active" || fail "expected a 'no active cycle' message when nothing to stop"

echo "PASS: commands/dev-flow/stop.md behavior"
