# Neutral State/Config Path Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `skills/dev-flow/SKILL.md` and its `spec-tool-*.md` references read the project config through the same neutral, client-agnostic path convention (`.codeflow/dev-flow.config.json`, overridable via `DEV_FLOW_CONFIG_FILE`) that `lib/state.sh` and `install.sh` already use for state, instead of hardcoding the legacy `.claude/dev-flow.config.json` path.

**Architecture:** `lib/state.sh` already exposes `state_file()` as the sole state-path API (default `.codeflow/dev-flow-state.json`, override `DEV_FLOW_STATE_FILE`). Add a matching `config_file()` function for config, then repoint every literal `.claude/dev-flow-state.json` / `.claude/dev-flow.config.json` reference in the canonical `skills/dev-flow/` source tree (which `install.sh`'s `copy_skill()` copies verbatim into `.claude/`, `.codex/`, and `.cursor/`) to the neutral convention. Finish by syncing the two openspec specs whose requirement text still states the legacy path literally.

**Tech Stack:** Bash, jq, Markdown, shell tests (grep-based structural assertions, consistent with the rest of this repo's test suite).

## Global Constraints

- Canonical state path: `.codeflow/dev-flow-state.json`, override env var `DEV_FLOW_STATE_FILE` (already shipped in `lib/state.sh`).
- Canonical config path: `.codeflow/dev-flow.config.json`, override env var `DEV_FLOW_CONFIG_FILE` (documented in `docs/platform-integration-contracts.md`, not yet implemented).
- `install.sh`'s `copy_skill()` does `cp -R skills/dev-flow/. <target>/` — any literal path left in `skills/dev-flow/SKILL.md` or `skills/dev-flow/references/*.md` is copied verbatim into `.claude/`, `.codex/`, and `.cursor/` skill directories, so a Codex- or Cursor-only install (no `.claude/` directory at all) must never see a `.claude/`-rooted path in these files.
- Tests never write into this repository — fixture-based, `mktemp`-scoped, consistent with `tests/lib_state_test.sh`.
- No changes to `hooks/dev-flow-gate.sh` or `install.sh` — this plan is scoped to the config-path gap only; both already use `lib/state.sh` (state) or the correct migration pair (state+config) already.

---

### Task 1: Add `config_file()` to `lib/state.sh`

**Files:**
- Modify: `lib/state.sh`
- Test: `tests/lib_state_test.sh`

**Interfaces:**
- Produces: `config_file()` — a shell function, no arguments, echoes `"${DEV_FLOW_CONFIG_FILE:-.codeflow/dev-flow.config.json}"`. Later tasks (2 and 3) reference this function by name in Markdown prose, not by sourcing it from another script.

- [ ] **Step 1: Write the failing test**

Append to the end of `tests/lib_state_test.sh` (after the existing `echo "PASS: lib/state.sh (set_phase/increment_blocks)"` line):

```bash

# --- config_file defaults to the neutral .codeflow path ---
unset DEV_FLOW_CONFIG_FILE
[ "$(config_file)" = ".codeflow/dev-flow.config.json" ] || fail "config_file() should default to .codeflow/dev-flow.config.json"

# --- config_file honors the DEV_FLOW_CONFIG_FILE override ---
export DEV_FLOW_CONFIG_FILE="$TMPDIR_TEST/dev-flow.config.json"
[ "$(config_file)" = "$TMPDIR_TEST/dev-flow.config.json" ] || fail "config_file() should honor DEV_FLOW_CONFIG_FILE override"
unset DEV_FLOW_CONFIG_FILE

echo "PASS: lib/state.sh (config_file)"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/lib_state_test.sh`

Expected: FAIL with `config_file: command not found` (function does not exist yet).

- [ ] **Step 3: Implement `config_file()`**

In `lib/state.sh`, add the new function immediately after `state_file()` (which currently ends at line 8):

```bash
state_file() {
  echo "${DEV_FLOW_STATE_FILE:-.codeflow/dev-flow-state.json}"
}

config_file() {
  echo "${DEV_FLOW_CONFIG_FILE:-.codeflow/dev-flow.config.json}"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/lib_state_test.sh`

Expected: both `PASS: lib/state.sh (init/get/exists)`, `PASS: lib/state.sh (set_phase/increment_blocks)`, and `PASS: lib/state.sh (config_file)`.

- [ ] **Step 5: Commit**

```bash
git add lib/state.sh tests/lib_state_test.sh
git commit -m "feat: add config_file() neutral config path helper to lib/state.sh"
```

### Task 2: Repoint `skills/dev-flow/SKILL.md` to the neutral config path

**Files:**
- Modify: `skills/dev-flow/SKILL.md`
- Test: `tests/skill_structure_test.sh`

**Interfaces:**
- Consumes: `config_file()` from Task 1 (referenced by name in prose, the same way the file already references `state_file()`'s sibling functions like `state_init`/`state_get`/`state_set_phase`).

- [ ] **Step 1: Write the failing test**

Append to the end of `tests/skill_structure_test.sh` (before the final `echo "PASS: skills/dev-flow/SKILL.md structure"` line, so it runs as part of the same check):

```bash
if grep -qF '.claude/dev-flow-state.json' "$SKILL"; then
  fail "SKILL.md must not hardcode the legacy .claude/dev-flow-state.json path"
fi
if grep -qF '.claude/dev-flow.config.json' "$SKILL"; then
  fail "SKILL.md must not hardcode the legacy .claude/dev-flow.config.json path"
fi
grep -q 'config_file' "$SKILL" || fail "SKILL.md does not reference config_file() for reading project config"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/skill_structure_test.sh`

Expected: FAIL — `SKILL.md must not hardcode the legacy .claude/dev-flow-state.json path`.

- [ ] **Step 3: Update `skills/dev-flow/SKILL.md`**

Replace the "状态文件" section (current lines 14–35) with:

```markdown
## 状态文件

所有运行状态存的路径由 `lib/state.sh` 的 `state_file()` 返回(默认
`.codeflow/dev-flow-state.json`,可用 `DEV_FLOW_STATE_FILE` 环境变量
覆盖),字段:`feature`、`phase`、`blocks`、`spec_tool`。通过
`lib/state.sh` 提供的函数读写,不要直接用 jq/cat 手改这个文件:

- `state_init <feature> <spec_tool>` — 开始新一轮循环时调用一次
- `state_get <field>` — 读取字段
- `state_set_phase <phase>` — 切换到下一阶段时调用
- `state_increment_blocks` — 由 Stop hook 自己调用,skill 不需要手动调
- `config_file` — 返回项目配置文件路径(默认
  `.codeflow/dev-flow.config.json`,可用 `DEV_FLOW_CONFIG_FILE`
  环境变量覆盖),配置字段只读,不要创建或修改这个文件

这些函数定义在 `lib/state.sh` 里,每个 Bash 工具调用都是一个全新的
shell,函数不会跨调用保留。因此每次调用状态函数,必须和
`source lib/state.sh` 在同一次 Bash 调用里(或者当前 shell 已经
source 过),例如:

```bash
source lib/state.sh && state_set_phase "plan"
```

读取配置字段同理,例如:

```bash
source lib/state.sh && jq -r '.gate_command // empty' "$(config_file)"
```

以上所有操作都假定当前工作目录是项目根目录(`lib/state.sh` 的默认状态
文件路径和 source 路径都是相对路径)。
```

Then update the three remaining literal references to `.claude/dev-flow.config.json`:

In "## 启动新一轮循环", replace:
```markdown
1. 读取 `.claude/dev-flow.config.json` 的 `spec_tool` 字段(缺省视为
   `"openspec"`)
```
with:
```markdown
1. 读取 `config_file()` 路径下的 `spec_tool` 字段(缺省视为
   `"openspec"`)
```

In "### propose", replace:
```markdown
- **文件不存在**:不要猜测或跳过。执行 `state_set_phase "paused"`,
  向用户说明 `spec_tool` 配置的值没有对应的 reference 文件,请用户
  修正 `.claude/dev-flow.config.json` 后再继续。
```
with:
```markdown
- **文件不存在**:不要猜测或跳过。执行 `state_set_phase "paused"`,
  向用户说明 `spec_tool` 配置的值没有对应的 reference 文件,请用户
  修正 `config_file()` 路径下的配置文件后再继续。
```

In "### verify", replace:
```markdown
1. 读取 `.claude/dev-flow.config.json` 的 `gate_command` 字段:
```
with:
```markdown
1. 读取 `config_file()` 路径下的 `gate_command` 字段:
```

In "### archive", replace:
```markdown
- **文件不存在**:和 propose 阶段一样,不要猜测或跳过。执行
  `state_set_phase "paused"`,向用户说明 `spec_tool` 配置的值没有对应
  的 reference 文件,请用户修正 `.claude/dev-flow.config.json` 后再
  继续。
```
with:
```markdown
- **文件不存在**:和 propose 阶段一样,不要猜测或跳过。执行
  `state_set_phase "paused"`,向用户说明 `spec_tool` 配置的值没有对应
  的 reference 文件,请用户修正 `config_file()` 路径下的配置文件后再
  继续。
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/skill_structure_test.sh`

Expected: `PASS: skills/dev-flow/SKILL.md structure`.

- [ ] **Step 5: Commit**

```bash
git add skills/dev-flow/SKILL.md tests/skill_structure_test.sh
git commit -m "fix: repoint SKILL.md config reads to the neutral config_file() path"
```

### Task 3: Repoint `spec-tool-openspec.md` and `spec-tool-speckit.md` intro lines

**Files:**
- Modify: `skills/dev-flow/references/spec-tool-openspec.md`, `skills/dev-flow/references/spec-tool-speckit.md`
- Test: `tests/spec_tool_openspec_test.sh`, `tests/spec_tool_speckit_test.sh`

**Interfaces:**
- Consumes: nothing new (these files are read as plain text by the engine, not sourced).

- [ ] **Step 1: Write the failing tests**

Append to `tests/spec_tool_openspec_test.sh` (before the final `echo "PASS: ..."` line):

```bash
if grep -qF '.claude/dev-flow.config.json' "$FILE"; then
  fail "spec-tool-openspec.md must not hardcode the legacy .claude/dev-flow.config.json path"
fi
```

Append to `tests/spec_tool_speckit_test.sh` (before the final `echo "PASS: ..."` line):

```bash
if grep -qF '.claude/dev-flow.config.json' "$FILE"; then
  fail "spec-tool-speckit.md must not hardcode the legacy .claude/dev-flow.config.json path"
fi
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/spec_tool_openspec_test.sh && bash tests/spec_tool_speckit_test.sh`

Expected: first command FAILs with `spec-tool-openspec.md must not hardcode the legacy .claude/dev-flow.config.json path`.

- [ ] **Step 3: Update both reference files**

In `skills/dev-flow/references/spec-tool-openspec.md`, replace the intro paragraph:

```markdown
供 `dev-flow` 引擎在 `.claude/dev-flow.config.json` 的 `spec_tool`
配置为 `"openspec"` 时,在 propose 和 archive 阶段查阅。
```

with:

```markdown
供 `dev-flow` 引擎在项目配置文件(`lib/state.sh` 的 `config_file()`,
默认 `.codeflow/dev-flow.config.json`)的 `spec_tool` 配置为
`"openspec"` 时,在 propose 和 archive 阶段查阅。
```

In `skills/dev-flow/references/spec-tool-speckit.md`, replace the intro paragraph:

```markdown
供 `dev-flow` 引擎在 `.claude/dev-flow.config.json` 的 `spec_tool`
配置为 `"speckit"` 时,在 propose 和 archive 阶段查阅。
```

with:

```markdown
供 `dev-flow` 引擎在项目配置文件(`lib/state.sh` 的 `config_file()`,
默认 `.codeflow/dev-flow.config.json`)的 `spec_tool` 配置为
`"speckit"` 时,在 propose 和 archive 阶段查阅。
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/spec_tool_openspec_test.sh && bash tests/spec_tool_speckit_test.sh && bash tests/spec_tool_adapter_consistency_test.sh`

Expected: all three `PASS:` lines (the consistency test re-validates both files still share the same section-header contract, unaffected by this wording change).

- [ ] **Step 5: Commit**

```bash
git add skills/dev-flow/references/spec-tool-openspec.md skills/dev-flow/references/spec-tool-speckit.md tests/spec_tool_openspec_test.sh tests/spec_tool_speckit_test.sh
git commit -m "fix: repoint spec-tool reference files to the neutral config_file() path"
```

### Task 4: Sync the two stale openspec specs

**Files:**
- Modify: `openspec/specs/orchestration-engine/spec.md`, `openspec/specs/spec-tool-adapter/spec.md`

**Interfaces:**
- Consumes: nothing (documentation-only; these specs were never given a MODIFIED-requirements delta when `cross-platform-installer` introduced the neutral `.codeflow/` paths, so their requirement text still literally states the legacy `.claude/` paths — this task is a documentation sync, not a behavior change, matching the precedent already set for these two specs on 2026-07-15).

- [ ] **Step 1: Update `openspec/specs/orchestration-engine/spec.md`**

Replace (line 14):

```markdown
The engine SHALL persist run-level state in `.claude/dev-flow-state.json` with fields `feature` (string), `phase` (string), `blocks` (integer, default 0), and `spec_tool` (string). The engine SHALL create this file when a cycle starts and SHALL update `phase` as the cycle advances.
```

with:

```markdown
The engine SHALL persist run-level state at the path `lib/state.sh`'s `state_file()` returns (default `.codeflow/dev-flow-state.json`, overridable via `DEV_FLOW_STATE_FILE`) with fields `feature` (string), `phase` (string), `blocks` (integer, default 0), and `spec_tool` (string). The engine SHALL create this file when a cycle starts and SHALL update `phase` as the cycle advances.
```

Replace (line 61):

```markdown
The engine SHALL read three fields from `.claude/dev-flow.config.json` if present: `spec_tool` (string, selects the propose/archive delegation target), `gate_command` (string, shell command run at the `verify` phase), and `codex_review` (boolean, whether to invoke `/codex:review` at the `verify` phase). The engine SHALL NOT create or modify this file.
```

with:

```markdown
The engine SHALL read three fields from the path `lib/state.sh`'s `config_file()` returns (default `.codeflow/dev-flow.config.json`, overridable via `DEV_FLOW_CONFIG_FILE`) if present: `spec_tool` (string, selects the propose/archive delegation target), `gate_command` (string, shell command run at the `verify` phase), and `codex_review` (boolean, whether to invoke `/codex:review` at the `verify` phase). The engine SHALL NOT create or modify this file.
```

- [ ] **Step 2: Update `openspec/specs/spec-tool-adapter/spec.md`**

Replace (line 10):

```markdown
- **WHEN** `.claude/dev-flow.config.json` has `spec_tool` set to `"openspec"`
```

with:

```markdown
- **WHEN** the project config file (`config_file()`'s path, default `.codeflow/dev-flow.config.json`) has `spec_tool` set to `"openspec"`
```

Replace (line 14):

```markdown
- **WHEN** `.claude/dev-flow.config.json` has `spec_tool` set to `"speckit"`
```

with:

```markdown
- **WHEN** the project config file (`config_file()`'s path, default `.codeflow/dev-flow.config.json`) has `spec_tool` set to `"speckit"`
```

- [ ] **Step 3: Verify no stale literal paths remain in either spec**

Run:
```bash
grep -n '\.claude/dev-flow' openspec/specs/orchestration-engine/spec.md openspec/specs/spec-tool-adapter/spec.md
```

Expected: no output (exit code 1 from `grep -n` finding nothing).

- [ ] **Step 4: Commit**

```bash
git add openspec/specs/orchestration-engine/spec.md openspec/specs/spec-tool-adapter/spec.md
git commit -m "docs: sync orchestration-engine and spec-tool-adapter specs to the neutral config path"
```

### Task 5: Full regression run

**Files:** none (verification only).

- [ ] **Step 1: Run the complete test suite**

```bash
for t in tests/*_test.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```

Expected: every test prints a line starting with `PASS:`, no `FAIL:` lines, exit code 0.

- [ ] **Step 2: Confirm no leftover legacy path references anywhere in the canonical source tree**

```bash
grep -rn '\.claude/dev-flow-state\.json\|\.claude/dev-flow\.config\.json' skills/ commands/ openspec/specs/ 2>/dev/null
```

Expected: no output.

## Self-Review

**Spec coverage:** The gap identified was that `skills/dev-flow/SKILL.md` (the canonical source `install.sh`'s `copy_skill()` copies verbatim into every client target) and its two `spec-tool-*.md` references still hardcoded the legacy `.claude/` config path, contradicting the neutral `.codeflow/` convention `lib/state.sh`/`install.sh` already ship, and violating `client-workflow-adapters`'s "SHALL not require another client's directory at runtime" requirement for Codex/Cursor installs. Task 1 adds the missing `config_file()` API (mirroring the existing `state_file()`). Task 2 fixes the canonical `SKILL.md`. Task 3 fixes both spec-tool reference files. Task 4 syncs the two openspec specs whose requirement text was never updated with a MODIFIED delta. Task 5 confirms no regressions and no leftover literal legacy paths anywhere in the canonical tree. All identified instances (grep-verified: `install.sh`, `lib/state.sh`, `SKILL.md` ×4, `spec-tool-openspec.md`, `spec-tool-speckit.md`, `orchestration-engine/spec.md` ×2, `spec-tool-adapter/spec.md` ×2) are covered.

**Placeholder scan:** No TBD/TODO/"handle appropriately" — every step shows exact before/after text or exact test code.

**Type/name consistency check:** `config_file()` (Task 1) is referenced by that exact name in Task 2's `SKILL.md` prose, Task 3's reference-file prose, and Task 4's spec prose — verified consistent. `DEV_FLOW_CONFIG_FILE` env var name matches `docs/platform-integration-contracts.md`'s existing documentation exactly.
