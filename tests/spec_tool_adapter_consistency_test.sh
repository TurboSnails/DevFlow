#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENSPEC_FILE="$SCRIPT_DIR/../skills/dev-flow/references/spec-tool-openspec.md"
SPECKIT_FILE="$SCRIPT_DIR/../skills/dev-flow/references/spec-tool-speckit.md"

fail() { echo "FAIL: $1"; exit 1; }

for f in "$OPENSPEC_FILE" "$SPECKIT_FILE"; do
  grep -qF '## propose 阶段做什么' "$f" || fail "$f missing propose section header"
  grep -qF '## archive 阶段做什么' "$f" || fail "$f missing archive section header"
done

if grep -q '/speckit\.' "$OPENSPEC_FILE"; then
  fail "spec-tool-openspec.md must not reference /speckit.* commands"
fi

if grep -q '/opsx:' "$SPECKIT_FILE"; then
  fail "spec-tool-speckit.md must not reference /opsx:* commands"
fi

echo "PASS: spec-tool-adapter reference files are consistent and mutually exclusive"
