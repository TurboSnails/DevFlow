#!/usr/bin/env bash
# lib/state.sh - dev-flow run-state read/write helpers.
# All functions operate on the file returned by state_file().
set -euo pipefail

state_file() {
  echo "${DEV_FLOW_STATE_FILE:-.claude/dev-flow-state.json}"
}

state_exists() {
  [ -f "$(state_file)" ]
}

state_init() {
  local feature="$1"
  local spec_tool="$2"
  local file
  file="$(state_file)"
  mkdir -p "$(dirname "$file")"
  jq -n \
    --arg feature "$feature" \
    --arg phase "propose" \
    --arg spec_tool "$spec_tool" \
    '{feature: $feature, phase: $phase, blocks: 0, spec_tool: $spec_tool}' \
    > "$file"
}

state_get() {
  local field="$1"
  jq -r --arg f "$field" '.[$f]' "$(state_file)"
}
