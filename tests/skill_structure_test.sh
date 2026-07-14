#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$SCRIPT_DIR/../skills/dev-flow/SKILL.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$SKILL" ] || fail "SKILL.md does not exist"
grep -q '^name: dev-flow$' "$SKILL" || fail "missing 'name: dev-flow' in frontmatter"
grep -q '^description:' "$SKILL" || fail "missing 'description:' in frontmatter"

for phase in propose await-approval plan build verify ship archive done; do
  grep -qi "$phase" "$SKILL" || fail "SKILL.md does not mention phase: $phase"
done

grep -q 'references/spec-tool-' "$SKILL" || fail "SKILL.md does not reference the spec-tool-<value>.md delegation convention"
grep -q '/gs:ship' "$SKILL" || fail "SKILL.md does not reference /gs:ship delegation"
grep -q 'state_init' "$SKILL" || fail "SKILL.md does not document calling state_init at cycle start"
grep -q 'state_set_phase' "$SKILL" || fail "SKILL.md does not document calling state_set_phase between phases"
grep -q 'gate_command' "$SKILL" || fail "SKILL.md does not document reading gate_command at verify phase"
grep -q 'codex_review' "$SKILL" || fail "SKILL.md does not document reading codex_review at verify phase"
grep -qi 'paused' "$SKILL" || fail "SKILL.md does not document the missing-reference-file pause behavior"

echo "PASS: skills/dev-flow/SKILL.md structure"
