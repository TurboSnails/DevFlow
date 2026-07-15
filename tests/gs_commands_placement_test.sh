#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

fail() { echo "FAIL: $1"; exit 1; }

for f in ship freeze office-hours retro cso; do
  path="$REPO_ROOT/commands/gs/$f.md"
  [ -f "$path" ] || fail "$path does not exist"
done

skill_count="$(find "$REPO_ROOT/skills" -name SKILL.md | wc -l | tr -d ' ')"
[ "$skill_count" = "1" ] || fail "expected exactly 1 SKILL.md under skills/, found $skill_count"

echo "PASS: gs commands stay under commands/gs/, dev-flow remains the sole auto-triggered skill"
