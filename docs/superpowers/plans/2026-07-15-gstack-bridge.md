# Gstack Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the five `/gs:*`/`/office-hours` commands the original project brief calls for (ship, freeze, office-hours, retro, cso), plus the PreToolUse hook that actually enforces `/gs:freeze`'s frozen-path declarations — unblocking `dev-flow`'s `ship` phase (which already invokes `/gs:ship` by name) and closing the last known gap from the original project scope.

**Architecture:** Five independent Markdown command files under `commands/gs/` (never `skills/`, preserving the single-auto-trigger rule). Two of them (`freeze.md`, and indirectly `ship.md`'s git/gh steps) embed a literal fenced bash snippet using this repo's established extraction-and-execute test pattern (from `cli-commands`); the other three (`office-hours.md`, `retro.md`, `cso.md`) are pure conversation templates with structural tests only, since they have no deterministic shell behavior to execute. One new hook, `hooks/freeze-gate.sh`, is the project's first non-Stop hook — a PreToolUse hook reading a JSON tool-invocation payload from stdin and blocking Edit/Write against frozen paths, using the same `{"decision":"block","reason":"..."}` output convention as the existing `hooks/dev-flow-gate.sh` for internal consistency.

**Tech Stack:** Markdown (command prompt files, some with embedded bash), bash test scripts (mix of real snippet-extraction execution and structural grep, per file).

## Global Constraints

- All five command files live under `commands/gs/`, never under any `skills/` directory — this is what keeps `dev-flow` the sole auto-triggered skill in the project; a `description:` frontmatter field is expected and fine (matches `cli-commands`' corrected understanding of this rule).
- `/gs:ship` must NOT include a merge step. Merging to the base branch is always a separate, manual action the user performs later — this is a deliberate scope change from an earlier draft of the design (which had `/gs:ship` pause for merge confirmation), corrected because `dev-flow`'s Stop hook has no way to know about a pause point inside the `ship` phase's command and would otherwise force continuation mid-merge-decision. By stopping short of merging entirely (never even offering to merge), `/gs:ship` can run to completion without needing any hidden pause, and the engine can safely advance straight to `archive` once CI has reported.
- `/gs:freeze` never gets an `/gs:unfreeze` counterpart — `.claude/frozen-paths.txt` is a plain, directly-editable text file (one path per line); removing a line un-freezes it.
- `freeze-gate.sh`'s path matching must never produce a partial-segment false positive — freezing `lib/core/payment` must not incorrectly match `lib/core/paylater`, and freezing an exact file `lib/core/auth/keys.json` must not incorrectly match `lib/core/auth/keys.json.bak`. Matching is: exact match, OR target starts with `normalized-entry + "/"` (where normalized-entry has any trailing `/**`, `/*`, or `/` stripped).
- `retro.md` and `cso.md` write nothing to disk — pure conversation templates.
- `office-hours.md`'s six questions and `retro.md`'s three questions must be asked one at a time in conversation, not answered by the assistant itself.

---

### Task 1: `hooks/freeze-gate.sh`

**Files:**
- Create: `hooks/freeze-gate.sh`
- Test: `tests/freeze_gate_test.sh`

**Interfaces:**
- Consumes: a JSON payload on stdin shaped `{"tool_name": "...", "tool_input": {"file_path": "..."}}`; reads `.claude/frozen-paths.txt` (path overridable via `FROZEN_PATHS_FILE` env var for testing, mirroring `lib/state.sh`'s `DEV_FLOW_STATE_FILE` pattern)
- Produces: always exits 0; prints `{"decision":"block","reason":"..."}` on stdout to block, or nothing to allow — same contract shape as `hooks/dev-flow-gate.sh`

- [ ] **Step 1: Write the failing test covering all branches**

Create `tests/freeze_gate_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../hooks/freeze-gate.sh"

fail() { echo "FAIL: $1"; exit 1; }

TMPDIR_TEST="$(mktemp -d)"
export FROZEN_PATHS_FILE="$TMPDIR_TEST/frozen-paths.txt"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

payload() {
  local path="$1"
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$path"
}

# 1. No frozen-paths file at all -> allow
rm -f "$FROZEN_PATHS_FILE"
output="$(payload "lib/core/payment/api.ts" | "$HOOK")"
[ -z "$output" ] || fail "expected allow (no output) when no frozen-paths file exists"

# 2. Frozen directory entry with /** suffix
cat > "$FROZEN_PATHS_FILE" <<'EOF'
lib/core/payment/**
lib/core/auth/keys.json
EOF

output="$(payload "lib/core/payment/api.ts" | "$HOOK")"
echo "$output" | grep -q '"decision":"block"' || fail "expected block for path under frozen directory lib/core/payment/**"

# 3. Similarly-named sibling directory must NOT match (no partial segment matching)
output="$(payload "lib/core/paylater/x.ts" | "$HOOK")"
[ -z "$output" ] || fail "expected allow for lib/core/paylater/x.ts (must not partially match lib/core/payment)"

# 4. Exact frozen file entry (no wildcard)
output="$(payload "lib/core/auth/keys.json" | "$HOOK")"
echo "$output" | grep -q '"decision":"block"' || fail "expected block for exact frozen file lib/core/auth/keys.json"

# 5. Similarly-named sibling file must NOT match
output="$(payload "lib/core/auth/keys.json.bak" | "$HOOK")"
[ -z "$output" ] || fail "expected allow for lib/core/auth/keys.json.bak (must not partially match keys.json)"

# 6. Unrelated path -> allow
output="$(payload "src/index.ts" | "$HOOK")"
[ -z "$output" ] || fail "expected allow for unrelated path"

# 7. Comment lines and blank lines must not cause errors or false blocks
cat >> "$FROZEN_PATHS_FILE" <<'EOF'

# this is a comment
EOF
output="$(payload "src/index.ts" | "$HOOK")"
[ -z "$output" ] || fail "expected allow still, comments/blank lines must not cause errors or false blocks"

echo "PASS: hooks/freeze-gate.sh"
```

Make it executable:

```bash
chmod +x tests/freeze_gate_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/freeze_gate_test.sh`
Expected: FAIL — `hooks/freeze-gate.sh: No such file or directory`

- [ ] **Step 3: Write the hook**

Create `hooks/freeze-gate.sh`:

```bash
#!/usr/bin/env bash
# hooks/freeze-gate.sh - PreToolUse hook blocking Edit/Write on frozen paths.
# Frozen paths are declared one per line in .claude/frozen-paths.txt
# (plain text, directly editable - see commands/gs/freeze.md).
set -euo pipefail

frozen_file() {
  echo "${FROZEN_PATHS_FILE:-.claude/frozen-paths.txt}"
}

FILE="$(frozen_file)"
[ -f "$FILE" ] || exit 0

payload="$(cat)"
target="$(echo "$payload" | jq -r '.tool_input.file_path // empty')"
[ -n "$target" ] || exit 0

while IFS= read -r entry || [ -n "$entry" ]; do
  [ -z "$entry" ] && continue
  case "$entry" in
    \#*) continue ;;
  esac

  normalized="${entry%/\*\*}"
  normalized="${normalized%/\*}"
  normalized="${normalized%/}"

  if [ "$target" = "$normalized" ] || [[ "$target" == "$normalized"/* ]]; then
    echo "{\"decision\":\"block\",\"reason\":\"Path '$target' is frozen (matches '$entry' in .claude/frozen-paths.txt) and cannot be edited.\"}"
    exit 0
  fi
done < "$FILE"

exit 0
```

Make it executable:

```bash
chmod +x hooks/freeze-gate.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/freeze_gate_test.sh`
Expected: `PASS: hooks/freeze-gate.sh`

- [ ] **Step 5: Commit**

```bash
git add hooks/freeze-gate.sh tests/freeze_gate_test.sh
git commit -m "feat: add freeze-gate PreToolUse hook blocking edits to frozen paths"
```

---

### Task 2: `commands/gs/freeze.md`

**Files:**
- Create: `commands/gs/freeze.md`
- Test: `tests/gs_freeze_test.sh`

**Interfaces:**
- Consumes: nothing (writes directly to `.claude/frozen-paths.txt`, the same file `hooks/freeze-gate.sh` reads — no shared library, since this file is meant to be a plain, hand-editable text file)
- Produces: `.claude/frozen-paths.txt` entries that Task 1's hook consumes

- [ ] **Step 1: Write the failing test**

Create `tests/gs_freeze_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/freeze.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "freeze.md does not exist"

SNIPPET="$(sed -n '/^```bash$/,/^```$/p' "$FILE" | sed '1d;$d')"
[ -n "$SNIPPET" ] || fail "no fenced bash snippet found in freeze.md"

TMPDIR_TEST="$(mktemp -d)"
export ARGUMENTS="lib/core/payment"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

output="$(cd "$TMPDIR_TEST" && eval "$SNIPPET")"
echo "$output" | grep -q "Frozen: lib/core/payment" || fail "expected 'Frozen: lib/core/payment' on first freeze"
[ -f "$TMPDIR_TEST/.claude/frozen-paths.txt" ] || fail "expected .claude/frozen-paths.txt to be created"
[ "$(wc -l < "$TMPDIR_TEST/.claude/frozen-paths.txt" | tr -d ' ')" = "1" ] || fail "expected exactly one line after first freeze"

# Freezing the same path again reports already-frozen, does not duplicate the line
output="$(cd "$TMPDIR_TEST" && eval "$SNIPPET")"
echo "$output" | grep -q "Already frozen: lib/core/payment" || fail "expected 'Already frozen' on second freeze of same path"
[ "$(wc -l < "$TMPDIR_TEST/.claude/frozen-paths.txt" | tr -d ' ')" = "1" ] || fail "expected still exactly one line, no duplicate"

echo "PASS: commands/gs/freeze.md behavior"
```

Make it executable:

```bash
chmod +x tests/gs_freeze_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/gs_freeze_test.sh`
Expected: FAIL — `freeze.md does not exist`

- [ ] **Step 3: Write the command file**

Create `commands/gs/freeze.md`:

```markdown
---
name: "GS: Freeze"
description: Mark a path as frozen — off-limits for AI-driven edits
category: Workflow
tags: [workflow, gstack-bridge, freeze]
---

Mark a path (file or directory) as frozen: off-limits for AI-driven
edits, enforced by `hooks/freeze-gate.sh`.

**Input**: The argument after `/gs:freeze` is the path to freeze,
relative to the project root, e.g. `/gs:freeze lib/core/payment`.

Run this exact shell command from the project root, then report its
output to the user verbatim:

```bash
path="$ARGUMENTS"
file=".claude/frozen-paths.txt"
mkdir -p "$(dirname "$file")"
touch "$file"
if grep -qxF "$path" "$file"; then
  echo "Already frozen: $path"
else
  echo "$path" >> "$file"
  echo "Frozen: $path"
fi
```

To unfreeze, remove the corresponding line from
`.claude/frozen-paths.txt` directly — there is no separate unfreeze
command.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/gs_freeze_test.sh`
Expected: `PASS: commands/gs/freeze.md behavior`

- [ ] **Step 5: Commit**

```bash
git add commands/gs/freeze.md tests/gs_freeze_test.sh
git commit -m "feat: add /gs:freeze command declaring frozen paths"
```

---

### Task 3: `commands/gs/ship.md`

**Files:**
- Create: `commands/gs/ship.md`
- Test: `tests/gs_ship_test.sh`

**Interfaces:**
- Consumes: `git`, `gh` CLI (not invoked by the test — this file is structurally tested only, since real git push/PR/CI operations aren't reproducible in a unit test)
- Produces: this is the command `dev-flow`'s `ship` phase (`skills/dev-flow/SKILL.md`, already shipped) invokes by name

- [ ] **Step 1: Write the failing structural test**

Create `tests/gs_ship_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/ship.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "ship.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"
grep -q 'git push' "$FILE" || fail "does not mention git push"
grep -q 'gh pr create' "$FILE" || fail "does not mention gh pr create"
grep -qi 'CI' "$FILE" || fail "does not mention waiting for CI"

if grep -q 'gh pr merge' "$FILE"; then
  fail "must not instruct running gh pr merge - merging is out of scope for this command"
fi

grep -qi 'manual' "$FILE" || fail "does not document that merging is a separate manual step"

echo "PASS: commands/gs/ship.md structure"
```

Make it executable:

```bash
chmod +x tests/gs_ship_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/gs_ship_test.sh`
Expected: FAIL — `ship.md does not exist`

- [ ] **Step 3: Write the command file**

Create `commands/gs/ship.md`:

```markdown
---
name: "GS: Ship"
description: Commit, push, open a PR, and wait for CI — merging is a separate manual step
category: Workflow
tags: [workflow, gstack-bridge, ship]
---

Ship the current branch's pending changes: commit, push, open a pull
request, and wait for CI to finish. This command does NOT merge —
merging is always a separate, manual step the user performs later
(via `gh pr merge` or the GitHub UI), so this command can run to
completion without needing a human checkpoint mid-way.

Steps:
1. Run `git status --short`. If there are uncommitted changes, stage
   and commit them with a Conventional Commits message describing the
   change.
2. Push the current branch: `git push -u origin HEAD`.
3. Create a pull request: `gh pr create --fill` (or with an explicit
   title/body if one was already drafted in this conversation).
4. Wait for CI to complete: `gh pr checks --watch` (or equivalent)
   until all checks finish.
5. Report the CI result (pass/fail, and which checks if any failed)
   to the user. Stop here — do not run `gh pr merge` under any
   circumstance in this command.

This command is what `dev-flow`'s `ship` phase (see
`skills/dev-flow/SKILL.md`) invokes by name. Because this command never
pauses for a merge decision, `dev-flow`'s Stop hook (which has no
knowledge of any pause point inside `ship`) can safely force
continuation once this command finishes — the engine advances straight
to `archive` once the PR is open and CI has reported, without waiting
for an actual merge.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/gs_ship_test.sh`
Expected: `PASS: commands/gs/ship.md structure`

- [ ] **Step 5: Commit**

```bash
git add commands/gs/ship.md tests/gs_ship_test.sh
git commit -m "feat: add /gs:ship command satisfying the dev-flow ship-phase contract"
```

---

### Task 4: Stateless conversation templates (`office-hours.md`, `retro.md`, `cso.md`)

**Files:**
- Create: `commands/gs/office-hours.md`
- Create: `commands/gs/retro.md`
- Create: `commands/gs/cso.md`
- Test: `tests/gs_office_hours_test.sh`
- Test: `tests/gs_retro_test.sh`
- Test: `tests/gs_cso_test.sh`

**Interfaces:**
- Consumes: nothing — pure conversation-shape prompt templates, no shell snippet, no state
- Produces: nothing consumed by other files in this plan

- [ ] **Step 1: Write the three failing structural tests**

Create `tests/gs_office_hours_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/office-hours.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "office-hours.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"

count="$(grep -cE '^[1-6]\. ' "$FILE")"
[ "$count" = "6" ] || fail "expected exactly 6 numbered questions, found $count"

grep -qi 'one at a time' "$FILE" || fail "does not instruct asking one at a time"

echo "PASS: commands/gs/office-hours.md structure"
```

Create `tests/gs_retro_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/retro.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "retro.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"

count="$(grep -cE '^[1-3]\. ' "$FILE")"
[ "$count" = "3" ] || fail "expected exactly 3 numbered questions, found $count"

grep -qi 'wait for the user' "$FILE" || fail "does not instruct waiting for user input on each question"

echo "PASS: commands/gs/retro.md structure"
```

Create `tests/gs_cso_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/gs/cso.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "cso.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"

count="$(grep -cE '^[1-4]\. ' "$FILE")"
[ "$count" = "4" ] || fail "expected exactly 4 checklist items, found $count"

grep -qF 'frozen-paths.txt' "$FILE" || fail "does not cross-reference .claude/frozen-paths.txt"

echo "PASS: commands/gs/cso.md structure"
```

Make them executable:

```bash
chmod +x tests/gs_office_hours_test.sh tests/gs_retro_test.sh tests/gs_cso_test.sh
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/gs_office_hours_test.sh; bash tests/gs_retro_test.sh; bash tests/gs_cso_test.sh`
Expected: all three FAIL — files do not exist

- [ ] **Step 3: Write the three command files**

Create `commands/gs/office-hours.md`:

```markdown
---
name: "Office Hours"
description: Six mandatory questions to answer before writing a spec
category: Workflow
tags: [workflow, gstack-bridge, product-thinking]
---

Before writing a spec for a non-trivial feature, work through these
six questions with the user, one at a time. The goal is to catch "the
wrong product, correctly specified" before any spec gets written.

1. 这个功能的用户是谁?他们现在怎么解决这个问题的(哪怕办法很笨)?
2. 如果不做这个功能,会发生什么?代价具体是什么?
3. 怎么量化"这个功能做成了"?用什么指标判断?
4. 第一版最小能做到多小?现在设想的范围里,哪些可以先砍掉?
5. 这个决定该由谁拍板?为什么是现在做,不是以后?
6. 如果这个功能最后失败了,最可能的原因会是什么?

Do not skip ahead to spec-writing until all six have real answers (not
placeholders). If an answer reveals the feature shouldn't be built as
scoped, say so plainly before proceeding.
```

Create `commands/gs/retro.md`:

```markdown
---
name: "GS: Retro"
description: Structured weekly retrospective conversation
category: Workflow
tags: [workflow, gstack-bridge, retro]
---

Run a structured retrospective conversation. Ask, one at a time, and
wait for the user's answer before moving to the next question:

1. 这周完成了什么?(具体列出来,不是笼统的"进展顺利")
2. 有什么卡住了,或者比预期慢?原因是什么?
3. 下周的计划是什么?最重要的一件事是什么?

This is a conversation, not a report to generate — do not answer all
three yourself.
```

Create `commands/gs/cso.md`:

```markdown
---
name: "GS: CSO"
description: Security audit checklist for sensitive changes
category: Workflow
tags: [workflow, gstack-bridge, security]
---

Run a security audit checklist against the current branch's changes.
Check each item and report a clear finding for each (nothing found /
found: <what>), not a vague "looks fine":

1. **密钥/凭证**:diff 里有没有新增的 API key、token、密码、连接串等
   硬编码内容?
2. **权限变更**:有没有修改访问控制、认证逻辑、角色权限的代码?如果
   有,逻辑是变严格还是变宽松?
3. **依赖**:本次改动有没有新增第三方依赖?是否有已知漏洞(可用
   `npm audit` 或等价工具核实)?
4. **冻结区**:本次改动有没有触碰 `.claude/frozen-paths.txt` 里声明
   的路径?如果 `hooks/freeze-gate.sh` 正常工作,这类改动本应被拦截
   ——如果发现绕过了,单独指出。
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/gs_office_hours_test.sh; bash tests/gs_retro_test.sh; bash tests/gs_cso_test.sh`
Expected: all three PASS

- [ ] **Step 5: Commit**

```bash
git add commands/gs/office-hours.md commands/gs/retro.md commands/gs/cso.md \
        tests/gs_office_hours_test.sh tests/gs_retro_test.sh tests/gs_cso_test.sh
git commit -m "feat: add office-hours, retro, and cso stateless conversation templates"
```

---

### Task 5: Cross-cutting placement check and full suite verification

**Files:**
- Create: `tests/gs_commands_placement_test.sh`

**Interfaces:**
- Consumes: the five command files from Tasks 2-4, checked by path only (no execution)

- [ ] **Step 1: Write the test**

Create `tests/gs_commands_placement_test.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x tests/gs_commands_placement_test.sh
```

- [ ] **Step 2: Run test to verify it passes**

This test should pass immediately once Tasks 1-4 are committed correctly — run it once as a verification gate:

Run: `bash tests/gs_commands_placement_test.sh`
Expected: `PASS: gs commands stay under commands/gs/, dev-flow remains the sole auto-triggered skill`

- [ ] **Step 3: Run the full test suite together (all gstack-bridge tests plus the entire existing suite, to confirm no regressions)**

Run:
```bash
for t in tests/*.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```
Expected: every file prints a `PASS:` line, no `FAIL:` lines, exit code 0

- [ ] **Step 4: Commit**

```bash
git add tests/gs_commands_placement_test.sh
git commit -m "test: add placement check for gstack-bridge commands"
```

---

## Plan Self-Review

**Spec coverage** (against the design in `docs/superpowers/specs/2026-07-15-gstack-bridge-design.md`):
- `/gs:ship` satisfies the dev-flow contract, no merge step → Task 3
- `/gs:freeze` enforcement via new PreToolUse hook → Task 1 (hook) + Task 2 (declaration command)
- No partial-segment false positives in path matching → Task 1's test cases 3 and 5
- `/office-hours`, `/gs:retro`, `/gs:cso` stateless templates → Task 4
- All commands under `commands/gs/`, `dev-flow` remains sole auto-triggered skill → Task 5
All design decisions have a corresponding task and test. No gaps found.

**Placeholder scan:** No TBD/TODO, no vague "handle appropriately" phrasing — every step has literal file contents and literal test code.

**Type/name consistency check:** `FROZEN_PATHS_FILE` env var name and `.claude/frozen-paths.txt` default path are identical across Task 1 (hook) and Task 2 (freeze command) — Task 2 doesn't actually read the env var (it always writes to the literal relative path `.claude/frozen-paths.txt` since it's meant to run from the project root, same convention as `cli-commands`' `stop.md`/`status.md`), which is intentional and consistent with Task 1's default fallback path. `jq`'s `.tool_input.file_path` field name is used consistently and matches the payload shape both the hook and its test construct.

**Scope note (deviation from the presented design):** the `/gs:ship` merge-confirmation pause described during brainstorming was removed during planning once its conflict with `orchestration-engine`'s Stop-hook behavior became concrete — this is documented as a Global Constraint above and reflected in Task 3's design, not left as a silent inconsistency between the design doc and this plan.
