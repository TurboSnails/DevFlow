#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."

fail() { echo "FAIL: $1"; exit 1; }

for f in start stop status update; do
  path="$REPO_ROOT/commands/dev-flow/$f.md"
  [ -f "$path" ] || fail "$path does not exist"
done

# The invariant is placement under commands/, not skills/ — a description:
# field is expected and fine (matches other commands in this repo).
if [ -d "$REPO_ROOT/skills/dev-flow-start" ] || [ -d "$REPO_ROOT/skills/dev-flow-stop" ] || \
   [ -d "$REPO_ROOT/skills/dev-flow-status" ] || [ -d "$REPO_ROOT/skills/dev-flow-update" ]; then
  fail "found a skills/ directory shadowing one of the dev-flow commands — this would cause unintended auto-triggering"
fi

# skills/dev-flow/SKILL.md must remain the only SKILL.md in the repo's own skills/ tree
skill_count="$(find "$REPO_ROOT/skills" -name SKILL.md | wc -l | tr -d ' ')"
[ "$skill_count" = "1" ] || fail "expected exactly 1 SKILL.md under skills/, found $skill_count"

echo "PASS: cli-commands stay under commands/dev-flow/, dev-flow remains the sole auto-triggered skill"
