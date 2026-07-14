#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../skills/dev-flow/references/spec-tool-speckit.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "spec-tool-speckit.md does not exist"
grep -qF '## propose 阶段做什么' "$FILE" || fail "missing '## propose 阶段做什么' section header"
grep -qF '## archive 阶段做什么' "$FILE" || fail "missing '## archive 阶段做什么' section header"

for cmd in '/speckit.specify' '/speckit.clarify' '/speckit.plan' '/speckit.tasks'; do
  grep -qF "$cmd" "$FILE" || fail "does not mention $cmd"
done

specify_line=$(grep -n '/speckit.specify' "$FILE" | head -1 | cut -d: -f1)
clarify_line=$(grep -n '/speckit.clarify' "$FILE" | head -1 | cut -d: -f1)
plan_line=$(grep -n '/speckit.plan' "$FILE" | head -1 | cut -d: -f1)
tasks_line=$(grep -n '/speckit.tasks' "$FILE" | head -1 | cut -d: -f1)

[ "$specify_line" -lt "$clarify_line" ] || fail "specify must come before clarify"
[ "$clarify_line" -lt "$plan_line" ] || fail "clarify must come before plan"
[ "$plan_line" -lt "$tasks_line" ] || fail "plan must come before tasks"

grep -qF 'specs/' "$FILE" || fail "does not state the specs/<feature>/ directory formula"

if grep -qF '/speckit.implement' "$FILE"; then
  fail "must not mention /speckit.implement"
fi

grep -qF '不要在这里运行 `/speckit.constitution`' "$FILE" || fail "must document that /speckit.constitution is not run automatically here"

echo "PASS: skills/dev-flow/references/spec-tool-speckit.md structure"
