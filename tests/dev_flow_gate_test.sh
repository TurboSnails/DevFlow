#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/dev-flow-gate.sh"
source "$SCRIPT_DIR/../lib/state.sh"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# 1. No state file -> exit 0, no output
rm -f "$DEV_FLOW_STATE_FILE"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no output when no state file exists"

# 2. Mid-cycle phase (e.g. build) -> block decision, blocks incremented
state_init "add-user-auth" "openspec"
state_set_phase "build"
output="$("$GATE")"
echo "$output" | grep -q '"decision":"block"' || fail "expected block decision for phase=build"
[ "$(state_get blocks)" = "1" ] || fail "blocks should be incremented to 1 after one block"

# 3. phase=await-approval -> allow, no output; state_set_phase resets blocks
# to 0 on the phase change, and await-approval's gate call does not increment.
state_set_phase "await-approval"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no block output for await-approval"
[ "$(state_get blocks)" = "0" ] || fail "blocks should be reset to 0 by state_set_phase and stay there (await-approval does not increment)"

# 4. phase=done -> allow, no output
state_set_phase "done"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no block output for done"

# 5. phase=paused -> allow, no output
state_set_phase "paused"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no block output for paused"

# 6. blocks at boundary (39) -> block, increment to 40
state_set_phase "build"
tmp="$(mktemp)"
jq '.blocks = 39' "$DEV_FLOW_STATE_FILE" > "$tmp" && mv "$tmp" "$DEV_FLOW_STATE_FILE"
output="$("$GATE")"
echo "$output" | grep -q '"decision":"block"' || fail "expected block decision at blocks=39"
[ "$(state_get blocks)" = "40" ] || fail "blocks should be incremented to 40 at boundary"
# next call at blocks=40 should allow
output="$("$GATE")"
[ -z "$output" ] || fail "expected no block output once blocks cap (40) reached"

# 7. blocks at cap (40) -> allow even mid-cycle
state_set_phase "build"
tmp="$(mktemp)"
jq '.blocks = 40' "$DEV_FLOW_STATE_FILE" > "$tmp" && mv "$tmp" "$DEV_FLOW_STATE_FILE"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no block output once blocks cap (40) reached"

echo "PASS: hooks/dev-flow-gate.sh"
