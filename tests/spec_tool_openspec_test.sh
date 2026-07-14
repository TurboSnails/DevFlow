#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../skills/dev-flow/references/spec-tool-openspec.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "spec-tool-openspec.md does not exist"
grep -qF '## propose 阶段做什么' "$FILE" || fail "missing '## propose 阶段做什么' section header"
grep -qF '## archive 阶段做什么' "$FILE" || fail "missing '## archive 阶段做什么' section header"
grep -q '/opsx:propose' "$FILE" || fail "does not mention /opsx:propose"
grep -q '/opsx:archive' "$FILE" || fail "does not mention /opsx:archive"
grep -qF 'openspec/changes/' "$FILE" || fail "does not state the openspec/changes/<feature>/ directory formula"

echo "PASS: skills/dev-flow/references/spec-tool-openspec.md structure"
