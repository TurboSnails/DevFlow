#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/dev-flow-gate.sh"
source "$SCRIPT_DIR/../lib/state.sh"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

state_init "add-user-auth" "openspec"

# Phases where the gate must force continuation. state_set_phase resets
# blocks to 0 on every phase change, so a single gate call per phase should
# always bring blocks to exactly 1 -- it must NOT accumulate across phases.
BLOCKING_PHASES=(propose plan build verify ship archive)
for phase in "${BLOCKING_PHASES[@]}"; do
  state_set_phase "$phase"
  [ "$(state_get blocks)" = "0" ] || fail "blocks should be reset to 0 when entering phase=$phase"
  output="$("$GATE")"
  echo "$output" | grep -q '"decision":"block"' || fail "expected block at phase=$phase"
  [ "$(state_get blocks)" = "1" ] || fail "blocks should be 1 after one gate call in phase=$phase"
done

# await-approval must allow without incrementing blocks. The phase change
# itself resets blocks to 0 (from the 1 left over by the previous phase).
state_set_phase "await-approval"
[ "$(state_get blocks)" = "0" ] || fail "blocks should be reset to 0 entering await-approval"
output="$("$GATE")"
[ -z "$output" ] || fail "expected allow (no output) at await-approval"
[ "$(state_get blocks)" = "0" ] || fail "blocks must not increment at await-approval"

# done must allow without incrementing blocks
state_set_phase "done"
[ "$(state_get blocks)" = "0" ] || fail "blocks should be reset to 0 entering done"
output="$("$GATE")"
[ -z "$output" ] || fail "expected allow (no output) at done"
[ "$(state_get blocks)" = "0" ] || fail "blocks must not increment at done"

# Safety cap: force blocks to 39, one more block phase should hit 40 and still block,
# the call after that (at 40) must allow.
state_set_phase "build"
tmp="$(mktemp)"
jq '.blocks = 39' "$DEV_FLOW_STATE_FILE" > "$tmp" && mv "$tmp" "$DEV_FLOW_STATE_FILE"
output="$("$GATE")"
echo "$output" | grep -q '"decision":"block"' || fail "expected block at blocks=39 -> 40"
[ "$(state_get blocks)" = "40" ] || fail "blocks should reach exactly 40"

output="$("$GATE")"
[ -z "$output" ] || fail "expected allow once blocks cap (40) is reached, got: $output"

echo "PASS: full propose-to-done cycle honors phase sequence, await-approval pause, and 40-block safety cap"
