#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/state.sh"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# --- state_exists is false before init ---
if state_exists; then fail "state_exists should be false before init"; fi

# --- state_init creates the file with expected shape ---
state_init "add-user-auth" "openspec"
state_exists || fail "state_exists should be true after init"
[ "$(state_get feature)" = "add-user-auth" ] || fail "feature mismatch"
[ "$(state_get phase)" = "propose" ] || fail "initial phase should be propose"
[ "$(state_get blocks)" = "0" ] || fail "initial blocks should be 0"
[ "$(state_get spec_tool)" = "openspec" ] || fail "spec_tool mismatch"

echo "PASS: lib/state.sh (init/get/exists)"

# --- state_set_phase updates phase in place ---
state_set_phase "plan"
[ "$(state_get phase)" = "plan" ] || fail "state_set_phase did not update phase"

# --- state_increment_blocks increments by 1 each call ---
state_increment_blocks
state_increment_blocks
[ "$(state_get blocks)" = "2" ] || fail "state_increment_blocks did not increment twice"

echo "PASS: lib/state.sh (set_phase/increment_blocks)"
