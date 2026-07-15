#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
fail() { echo "FAIL: $1"; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
(cd "$tmp" && "$INSTALLER" all >/dev/null)
for path in .claude/skills/dev-flow/SKILL.md .codex/skills/dev-flow/SKILL.md .cursor/skills/dev-flow/SKILL.md; do [ -f "$tmp/$path" ] || fail "missing $path"; done
grep -q 'bash install.sh claude' "$tmp/.claude/commands/dev-flow/update.md" || fail "Claude update target missing"
grep -q 'bash install.sh cursor' "$tmp/.cursor/commands/dev-flow-update.md" || fail "Cursor update target missing"
for path in .claude/commands/gs/ship.md .claude/commands/gs/freeze.md .claude/commands/gs/office-hours.md .claude/commands/gs/retro.md .claude/commands/gs/cso.md \
            .cursor/commands/gs-ship.md .cursor/commands/gs-freeze.md .cursor/commands/gs-office-hours.md .cursor/commands/gs-retro.md .cursor/commands/gs-cso.md; do
  [ -f "$tmp/$path" ] || fail "missing $path"
done

[ "$(jq '[.hooks.Stop[]?.hooks[]? | select(.command == "bash hooks/dev-flow-gate.sh")] | length' "$tmp/.claude/settings.json")" = 1 ] || fail "Stop hook not registered after fresh install"
[ "$(jq '[.hooks.PreToolUse[]?.hooks[]? | select(.command == "bash hooks/freeze-gate.sh")] | length' "$tmp/.claude/settings.json")" = 1 ] || fail "PreToolUse freeze hook not registered after fresh install"

(cd "$tmp" && "$INSTALLER" all >/dev/null)
[ "$(jq '[.hooks.Stop[]?.hooks[]? | select(.command == "bash hooks/dev-flow-gate.sh")] | length' "$tmp/.claude/settings.json")" = 1 ] || fail "reinstall duplicated hook"
[ "$(jq '[.hooks.PreToolUse[]?.hooks[]? | select(.command == "bash hooks/freeze-gate.sh")] | length' "$tmp/.claude/settings.json")" = 1 ] || fail "reinstall duplicated freeze hook"
echo "PASS: installer integration"
