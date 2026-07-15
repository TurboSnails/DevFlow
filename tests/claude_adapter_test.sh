#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
fail() { echo "FAIL: $1"; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.claude"
printf '{"permissions":{"allow":["Bash(git status)"]}}\n' > "$tmp/.claude/settings.json"
(cd "$tmp" && "$INSTALLER" claude >/dev/null)
[ -f "$tmp/.claude/skills/dev-flow/SKILL.md" ] || fail "skill missing"
for command in start stop status update; do [ -f "$tmp/.claude/commands/dev-flow/$command.md" ] || fail "command $command missing"; done
jq -e '.permissions.allow[0] == "Bash(git status)"' "$tmp/.claude/settings.json" >/dev/null || fail "settings not preserved"
[ "$(jq '[.hooks.Stop[]?.hooks[]? | select(.command == "bash hooks/dev-flow-gate.sh")] | length' "$tmp/.claude/settings.json")" = 1 ] || fail "expected one hook"
(cd "$tmp" && "$INSTALLER" claude >/dev/null)
[ "$(jq '[.hooks.Stop[]?.hooks[]? | select(.command == "bash hooks/dev-flow-gate.sh")] | length' "$tmp/.claude/settings.json")" = 1 ] || fail "hook duplicated"
echo "PASS: Claude adapter"
