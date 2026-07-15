#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
fail() { echo "FAIL: $1"; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.claude"
printf '{"feature":"x","phase":"build","blocks":0}\n' > "$tmp/.claude/dev-flow-state.json"
printf '{"spec_tool":"openspec"}\n' > "$tmp/.claude/dev-flow.config.json"
(cd "$tmp" && "$INSTALLER" codex >/dev/null)
[ -f "$tmp/.codeflow/dev-flow-state.json" ] || fail "state was not migrated"
[ -f "$tmp/.codeflow/dev-flow.config.json" ] || fail "config was not migrated"
[ ! -e "$tmp/.claude/dev-flow-state.json" ] || fail "legacy state remains"
printf '{}' > "$tmp/.claude/dev-flow-state.json"
if (cd "$tmp" && "$INSTALLER" --dry-run codex) >/dev/null 2>&1; then fail "conflict must fail"; fi
echo "PASS: installer migration"
