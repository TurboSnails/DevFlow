#!/usr/bin/env bash
# hooks/freeze-gate.sh - PreToolUse hook blocking Edit/Write on frozen paths.
# Frozen paths are declared one per line in .claude/frozen-paths.txt
# (plain text, directly editable - see commands/gs/freeze.md).
set -euo pipefail

frozen_file() {
  echo "${FROZEN_PATHS_FILE:-.claude/frozen-paths.txt}"
}

FILE="$(frozen_file)"
[ -f "$FILE" ] || exit 0

payload="$(cat)"
target="$(echo "$payload" | jq -r '.tool_input.file_path // empty')"
[ -n "$target" ] || exit 0

while IFS= read -r entry || [ -n "$entry" ]; do
  [ -z "$entry" ] && continue
  case "$entry" in
    \#*) continue ;;
  esac

  normalized="${entry%/\*\*}"
  normalized="${normalized%/\*}"
  normalized="${normalized%/}"

  if [ "$target" = "$normalized" ] || [[ "$target" == "$normalized"/* ]]; then
    echo "{\"decision\":\"block\",\"reason\":\"Path '$target' is frozen (matches '$entry' in .claude/frozen-paths.txt) and cannot be edited.\"}"
    exit 0
  fi
done < "$FILE"

exit 0
