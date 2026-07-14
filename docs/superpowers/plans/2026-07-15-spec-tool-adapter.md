# Spec Tool Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unblock the `dev-flow` engine's `propose`/`archive` phases by adding the two reference files it already looks up by naming convention — one driving OpenSpec, one driving Spec Kit — so a configured `spec_tool` value no longer causes the engine to pause with "no reference file found."

**Architecture:** Two independent, self-contained Markdown reference files (`skills/dev-flow/references/spec-tool-openspec.md`, `skills/dev-flow/references/spec-tool-speckit.md`), each with exactly the two section headers the engine's SKILL.md already references verbatim. Each gets its own structural test (grep-based, same technique as `orchestration-engine`'s Task 3), plus one cross-file consistency test proving neither file leaks the other tool's commands.

**Tech Stack:** Markdown (prompt content, not executable), bash test scripts (grep-based structural assertions, consistent with the rest of this repo's test suite).

## Global Constraints

- Both reference files MUST contain the literal section headers `## propose 阶段做什么` and `## archive 阶段做什么` — these exact Chinese strings, because `skills/dev-flow/SKILL.md` (already shipped) references them verbatim at lines 58 and 94.
- `spec-tool-openspec.md` states the spec directory formula `openspec/changes/<feature>/`; `spec-tool-speckit.md` states `specs/<feature>/`.
- Spec Kit's propose section documents `/speckit.specify → /speckit.clarify → /speckit.plan → /speckit.tasks` in that exact order; it must NOT run `/speckit.constitution` (one-time, manual, project-level) or `/speckit.implement` (explicitly disallowed project-wide — Superpowers owns implementation).
- Spec Kit's archive section is a documented no-op — no command execution, but the section must exist and explain why.
- `spec-tool-openspec.md` must never reference any `/speckit.*` command; `spec-tool-speckit.md` must never reference any `/opsx:*` command.
- No changes to `lib/state.sh`, `hooks/dev-flow-gate.sh`, or `skills/dev-flow/SKILL.md` — this plan only adds new files under `skills/dev-flow/references/`.

---

### Task 1: `skills/dev-flow/references/spec-tool-openspec.md`

**Files:**
- Create: `skills/dev-flow/references/spec-tool-openspec.md`
- Test: `tests/spec_tool_openspec_test.sh`

**Interfaces:**
- Consumes: nothing (pure Markdown, read by the `dev-flow` skill at runtime, not sourced/executed)
- Produces: the file the engine looks up when `spec_tool` is `"openspec"`; must satisfy `orchestration-engine`'s existing lookup path `skills/dev-flow/references/spec-tool-<spec_tool>.md` and its two-section contract

- [ ] **Step 1: Write the failing structural test**

Create `tests/spec_tool_openspec_test.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x tests/spec_tool_openspec_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/spec_tool_openspec_test.sh`
Expected: FAIL — `spec-tool-openspec.md does not exist`

- [ ] **Step 3: Write the reference file content**

Create `skills/dev-flow/references/spec-tool-openspec.md`:

```markdown
# spec-tool: openspec

供 `dev-flow` 引擎在 `.claude/dev-flow.config.json` 的 `spec_tool`
配置为 `"openspec"` 时,在 propose 和 archive 阶段查阅。

## propose 阶段做什么

1. 执行 `/opsx:propose <feature>`,驱动到全部完成(proposal.md、
   design.md、specs/**/*.md、tasks.md 四个 artifact 都生成)。
   `<feature>` 使用运行状态里 `feature` 字段的值。
2. 该命令本身可能会向用户提出澄清问题——这是 propose 阶段设计上
   允许的交互,不违反"阶段之间不停顿"的规则,因为整个 propose 阶段
   本来就是在等待进入 `await-approval` 之前的正常工作过程。
3. 完成后,本轮循环的 spec 目录是:

   ```
   openspec/changes/<feature>/
   ```

   后续 `plan` 阶段基于这个目录生成实施计划。

## archive 阶段做什么

执行 `/opsx:archive`,把当前 `<feature>` 对应的 change 归档(delta 合并
回 `openspec/specs/`)。归档完成后,引擎照常把 `phase` 设为 `done`。
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/spec_tool_openspec_test.sh`
Expected: `PASS: skills/dev-flow/references/spec-tool-openspec.md structure`

- [ ] **Step 5: Commit**

```bash
git add skills/dev-flow/references/spec-tool-openspec.md tests/spec_tool_openspec_test.sh
git commit -m "feat: add spec-tool-openspec.md reference for dev-flow propose/archive delegation"
```

---

### Task 2: `skills/dev-flow/references/spec-tool-speckit.md`

**Files:**
- Create: `skills/dev-flow/references/spec-tool-speckit.md`
- Test: `tests/spec_tool_speckit_test.sh`

**Interfaces:**
- Consumes: nothing (pure Markdown)
- Produces: the file the engine looks up when `spec_tool` is `"speckit"`

- [ ] **Step 1: Write the failing structural test**

Create `tests/spec_tool_speckit_test.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x tests/spec_tool_speckit_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/spec_tool_speckit_test.sh`
Expected: FAIL — `spec-tool-speckit.md does not exist`

- [ ] **Step 3: Write the reference file content**

Create `skills/dev-flow/references/spec-tool-speckit.md`:

```markdown
# spec-tool: speckit

供 `dev-flow` 引擎在 `.claude/dev-flow.config.json` 的 `spec_tool`
配置为 `"speckit"` 时,在 propose 和 archive 阶段查阅。

## propose 阶段做什么

按顺序执行以下 Spec Kit 命令,`<feature>` 使用运行状态里 `feature`
字段的值:

1. `/speckit.specify` —— 生成功能规范
2. `/speckit.clarify` —— 逼问所有模糊点
3. `/speckit.plan` —— 技术方案(schema、API 契约、组件层级)
4. `/speckit.tasks` —— 任务清单

不要在这里运行 `/speckit.constitution`——它是项目级、一次性的宪法声明,
不属于单个功能的循环;项目首次接入 Spec Kit 时应该手动跑一次,而不是
由 dev-flow 自动触发。也不要运行 `/speckit.implement`——本项目统一由
Superpowers 负责执行,`/speckit.implement` 在项目里被明确禁用。

完成后,本轮循环的 spec 目录是:

```
specs/<feature>/
```

后续 `plan` 阶段基于这个目录生成实施计划。

## archive 阶段做什么

Spec Kit 没有归档概念。`specs/<feature>/` 下的 spec 文件本身就是永久
记录,这里不执行任何命令。引擎照常把 `phase` 设为 `done`,视为循环
正常结束。
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/spec_tool_speckit_test.sh`
Expected: `PASS: skills/dev-flow/references/spec-tool-speckit.md structure`

- [ ] **Step 5: Commit**

```bash
git add skills/dev-flow/references/spec-tool-speckit.md tests/spec_tool_speckit_test.sh
git commit -m "feat: add spec-tool-speckit.md reference for dev-flow propose/archive delegation"
```

---

### Task 3: Cross-file consistency test

**Files:**
- Create: `tests/spec_tool_adapter_consistency_test.sh`

**Interfaces:**
- Consumes: both reference files from Task 1 and Task 2 directly (read as plain text, no sourcing)

- [ ] **Step 1: Write the test**

Create `tests/spec_tool_adapter_consistency_test.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x tests/spec_tool_adapter_consistency_test.sh
```

- [ ] **Step 2: Run test to verify it passes**

This test should pass immediately once Tasks 1-2 are committed correctly (it re-validates properties both files should already have, not new behavior to implement) — run it once as a verification gate rather than expecting red-then-green:

Run: `bash tests/spec_tool_adapter_consistency_test.sh`
Expected: `PASS: spec-tool-adapter reference files are consistent and mutually exclusive`

- [ ] **Step 3: Run the full test suite together (all spec-tool-adapter tests plus the existing orchestration-engine suite, to confirm no regressions)**

Run:
```bash
for t in tests/lib_state_test.sh tests/dev_flow_gate_test.sh tests/skill_structure_test.sh tests/e2e_cycle_test.sh tests/spec_tool_openspec_test.sh tests/spec_tool_speckit_test.sh tests/spec_tool_adapter_consistency_test.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```
Expected: seven `PASS:` lines, no `FAIL:` lines, exit code 0

- [ ] **Step 4: Commit**

```bash
git add tests/spec_tool_adapter_consistency_test.sh
git commit -m "test: add cross-file consistency check for spec-tool-adapter reference files"
```

---

## Plan Self-Review

**Spec coverage** (against `openspec/changes/spec-tool-adapter/specs/spec-tool-adapter/spec.md`):
- Reference files match the naming convention → Task 1 Step 3, Task 2 Step 3 (file paths)
- Required section headers match the engine's literal contract → Task 1/2 Step 1 tests + Task 3 consistency test
- OpenSpec propose drives full proposal flow + directory formula → Task 1 Step 3
- OpenSpec archive drives real archival → Task 1 Step 3
- Spec Kit propose drives ordered command chain + directory formula + constitution/implement exclusions → Task 2 Step 1 (order assertions) + Step 3
- Spec Kit archive is a documented no-op → Task 2 Step 3
All 6 requirements have a corresponding task and test assertion. No gaps found.

**Placeholder scan:** No TBD/TODO, no vague "handle appropriately" phrasing — every step has literal file contents.

**Type/name consistency check:** File paths (`skills/dev-flow/references/spec-tool-openspec.md`, `skills/dev-flow/references/spec-tool-speckit.md`), section headers (`## propose 阶段做什么`, `## archive 阶段做什么`), and directory formulas (`openspec/changes/<feature>/`, `specs/<feature>/`) are identical, character-for-character, across the proposal, design, spec, and all three task's test files — verified consistent.
