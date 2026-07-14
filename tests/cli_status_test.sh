#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/dev-flow/status.md"
STATE_LIB="$SCRIPT_DIR/../lib/state.sh"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "status.md does not exist"

# Extract the single ```bash ... ``` fenced snippet
SNIPPET="$(sed -n '/^```bash$/,/^```$/p' "$FILE" | sed '1d;$d')"
[ -n "$SNIPPET" ] || fail "no fenced bash snippet found in status.md"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Case 1: active cycle exists ---
source "$STATE_LIB"
state_init "add-user-auth" "openspec"
state_set_phase "verify"
state_increment_blocks
before_checksum="$(md5sum "$DEV_FLOW_STATE_FILE" 2>/dev/null || shasum "$DEV_FLOW_STATE_FILE")"

output="$(cd "$SCRIPT_DIR/.." && eval "$SNIPPET")"
echo "$output" | grep -q "add-user-auth" || fail "status output does not mention the feature"
echo "$output" | grep -q "verify" || fail "status output does not mention the phase"
echo "$output" | grep -q "1" || fail "status output does not mention the blocks count"

after_checksum="$(md5sum "$DEV_FLOW_STATE_FILE" 2>/dev/null || shasum "$DEV_FLOW_STATE_FILE")"
[ "$before_checksum" = "$after_checksum" ] || fail "status must not modify the state file"

# --- Case 2: no active cycle ---
rm -f "$DEV_FLOW_STATE_FILE"
output="$(cd "$SCRIPT_DIR/.." && eval "$SNIPPET")"
echo "$output" | grep -qi "no active" || fail "expected a 'no active cycle' message"

echo "PASS: commands/dev-flow/status.md behavior"
