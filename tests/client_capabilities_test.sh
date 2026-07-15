#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MATRIX="$SCRIPT_DIR/../config/client-capabilities.json"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$MATRIX" ] || fail "capability matrix does not exist"
jq -e '
  .schema_version == 1 and
  (.clients | keys | sort == ["claude", "codex", "cursor"]) and
  all(.clients[];
    (.commands.controls | sort == ["start", "status", "stop", "update"]) and
    (.skill.entry_point | type == "string") and
    (.update.installer_target | type == "string")
  ) and
  .clients.claude.commands.entry_point == ".claude/commands/dev-flow/<control>.md" and
  .clients.claude.continuation_gate == {
    "availability": "available",
    "enforcement": "native-stop-hook"
  } and
  .clients.codex.commands.entry_point == null and
  .clients.codex.continuation_gate == {
    "availability": "unavailable",
    "enforcement": "prompt-guided"
  } and
  .clients.cursor.commands.entry_point == ".cursor/commands/dev-flow-<control>.md" and
  .clients.cursor.continuation_gate == {
    "availability": "unavailable",
    "enforcement": "prompt-guided"
  } and
  all(.clients | to_entries[]; .key == .value.update.installer_target)
' "$MATRIX" >/dev/null || fail "capability matrix does not match the platform integration contracts"

echo "PASS: client capability matrix"
