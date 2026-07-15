#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
fail() { echo "FAIL: $1"; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/codex"
output="$(cd "$tmp/codex" && "$INSTALLER" codex)"
[ -f "$tmp/codex/.codex/skills/dev-flow/SKILL.md" ] || fail "Codex skill missing"
[ ! -e "$tmp/codex/.claude" ] || fail "Codex wrote Claude files"
echo "$output" | grep -q 'codex.continuation_gate=unavailable' || fail "Codex fallback not reported"

mkdir -p "$tmp/cursor"
output="$(cd "$tmp/cursor" && "$INSTALLER" cursor)"
[ -f "$tmp/cursor/.cursor/skills/dev-flow/SKILL.md" ] || fail "Cursor skill missing"
for command in start stop status update; do
  [ -f "$tmp/cursor/.cursor/commands/dev-flow-$command.md" ] || fail "Cursor command $command missing"
done
[ ! -e "$tmp/cursor/.claude" ] || fail "Cursor wrote Claude files"
echo "$output" | grep -q 'cursor.continuation_gate=unavailable' || fail "Cursor fallback not reported"

echo "PASS: Codex and Cursor adapters"
