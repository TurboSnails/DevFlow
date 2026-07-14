# Orchestration Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `dev-flow` automation core — a state file, a Stop-hook gate, and a SKILL.md — that drives a fixed propose→ship cycle to completion without the user re-invoking commands after every stage, pausing only once for spec approval.

**Architecture:** Three layers, each independently testable: (1) `lib/state.sh` — pure bash+jq functions to create/read/update the run-state JSON file; (2) `hooks/dev-flow-gate.sh` — a Stop hook that reads state via layer 1 and decides block-vs-allow; (3) `skills/dev-flow/SKILL.md` — the auto-triggered skill whose prompt instructions drive phase transitions by calling into layer 1's schema and layer 2's contract. Layers 1–2 get real bash test scripts; layer 3 gets a structural grep-based check plus a scripted end-to-end dry run of the whole cycle.

**Tech Stack:** bash, jq (already confirmed present: `/opt/homebrew/bin/jq`), Claude Code skill/hook conventions.

## Global Constraints

- Exactly one skill (`dev-flow`) may be auto-triggered in this repo — no other file in this plan gets a `description:` frontmatter field that causes auto-triggering.
- Phase sequence is fixed and linear, never reordered or skipped: `propose → await-approval → plan → build → verify → ship → archive → done`.
- `await-approval` is the only phase where the Stop hook allows a stop without forcing continuation (besides `done`/`paused`).
- Forced-continuation cap is a hardcoded constant `40` (per design.md Open Questions — not read from config).
- The engine must never embed spec-tool-specific logic or ship-mechanism logic directly — only the naming conventions `references/spec-tool-<value>.md` and the command name `/gs:ship`.
- `lib/state.sh` is the only code that touches `.claude/dev-flow-state.json` directly; every other script/skill goes through its functions.
- All state-file paths in tests must be overridable via `DEV_FLOW_STATE_FILE` so tests never touch a real project's `.claude/` directory.

---

### Task 1: `lib/state.sh` — run-state read/write helpers

**Files:**
- Create: `lib/state.sh`
- Test: `tests/lib_state_test.sh`

**Interfaces:**
- Consumes: `jq` CLI, `DEV_FLOW_STATE_FILE` env var (optional override, defaults to `.claude/dev-flow-state.json`)
- Produces (used by Task 2 and Task 3):
  - `state_file()` → echoes the resolved state file path
  - `state_exists()` → returns 0 (true) if the file exists, 1 otherwise
  - `state_init(feature: string, spec_tool: string)` → creates the file with `{feature, phase: "propose", blocks: 0, spec_tool}`
  - `state_get(field: string)` → echoes the string value of that field (numbers echoed as their string form)
  - `state_set_phase(phase: string)` → updates `phase` in place
  - `state_increment_blocks()` → increments `blocks` in place by 1

- [ ] **Step 1: Write the failing test for `state_init`, `state_get`, `state_exists`**

Create `tests/lib_state_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/state.sh"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# --- state_exists is false before init ---
if state_exists; then fail "state_exists should be false before init"; fi

# --- state_init creates the file with expected shape ---
state_init "add-user-auth" "openspec"
state_exists || fail "state_exists should be true after init"
[ "$(state_get feature)" = "add-user-auth" ] || fail "feature mismatch"
[ "$(state_get phase)" = "propose" ] || fail "initial phase should be propose"
[ "$(state_get blocks)" = "0" ] || fail "initial blocks should be 0"
[ "$(state_get spec_tool)" = "openspec" ] || fail "spec_tool mismatch"

echo "PASS: lib/state.sh (init/get/exists)"
```

Make it executable:

```bash
chmod +x tests/lib_state_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/lib_state_test.sh`
Expected: FAIL — `lib/state.sh: No such file or directory` (the `source` line fails because `lib/state.sh` doesn't exist yet)

- [ ] **Step 3: Write minimal implementation for `state_file`, `state_init`, `state_get`, `state_exists`**

Create `lib/state.sh`:

```bash
#!/usr/bin/env bash
# lib/state.sh - dev-flow run-state read/write helpers.
# All functions operate on the file returned by state_file().
set -euo pipefail

state_file() {
  echo "${DEV_FLOW_STATE_FILE:-.claude/dev-flow-state.json}"
}

state_exists() {
  [ -f "$(state_file)" ]
}

state_init() {
  local feature="$1"
  local spec_tool="$2"
  local file
  file="$(state_file)"
  mkdir -p "$(dirname "$file")"
  jq -n \
    --arg feature "$feature" \
    --arg phase "propose" \
    --arg spec_tool "$spec_tool" \
    '{feature: $feature, phase: $phase, blocks: 0, spec_tool: $spec_tool}' \
    > "$file"
}

state_get() {
  local field="$1"
  jq -r --arg f "$field" '.[$f]' "$(state_file)"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/lib_state_test.sh`
Expected: `PASS: lib/state.sh (init/get/exists)`

- [ ] **Step 5: Commit**

```bash
git add lib/state.sh tests/lib_state_test.sh
git commit -m "feat: add state_init/state_get/state_exists for dev-flow state file"
```

- [ ] **Step 6: Write the failing test for `state_set_phase` and `state_increment_blocks`**

Append to `tests/lib_state_test.sh` (before the final `echo "PASS..."` line, replace that line with the block below plus a new final echo):

```bash
# --- state_set_phase updates phase in place ---
state_set_phase "plan"
[ "$(state_get phase)" = "plan" ] || fail "state_set_phase did not update phase"

# --- state_increment_blocks increments by 1 each call ---
state_increment_blocks
state_increment_blocks
[ "$(state_get blocks)" = "2" ] || fail "state_increment_blocks did not increment twice"

echo "PASS: lib/state.sh (set_phase/increment_blocks)"
```

- [ ] **Step 7: Run test to verify it fails**

Run: `bash tests/lib_state_test.sh`
Expected: FAIL — `state_set_phase: command not found`

- [ ] **Step 8: Write minimal implementation for `state_set_phase` and `state_increment_blocks`**

Append to `lib/state.sh`:

```bash

state_set_phase() {
  local phase="$1"
  local file tmp
  file="$(state_file)"
  tmp="$(mktemp)"
  jq --arg phase "$phase" '.phase = $phase' "$file" > "$tmp" && mv "$tmp" "$file"
}

state_increment_blocks() {
  local file tmp
  file="$(state_file)"
  tmp="$(mktemp)"
  jq '.blocks += 1' "$file" > "$tmp" && mv "$tmp" "$file"
}
```

- [ ] **Step 9: Run test to verify it passes**

Run: `bash tests/lib_state_test.sh`
Expected: both `PASS: lib/state.sh (init/get/exists)` and `PASS: lib/state.sh (set_phase/increment_blocks)` printed, exit code 0

- [ ] **Step 10: Commit**

```bash
git add lib/state.sh tests/lib_state_test.sh
git commit -m "feat: add state_set_phase/state_increment_blocks for dev-flow state file"
```

---

### Task 2: `hooks/dev-flow-gate.sh` — Stop hook block/allow logic

**Files:**
- Create: `hooks/dev-flow-gate.sh`
- Test: `tests/dev_flow_gate_test.sh`

**Interfaces:**
- Consumes: `lib/state.sh` functions from Task 1 (`state_exists`, `state_get`, `state_set_phase`, `state_increment_blocks`) via `source "$SCRIPT_DIR/../lib/state.sh"`
- Produces (used by Task 3's manual/e2e verification and by the real Claude Code Stop hook registration): a script that always exits `0` and prints either nothing (allow) or a single-line JSON object `{"decision":"block","reason":"..."}` (force continue) on stdout

- [ ] **Step 1: Write the failing test covering all branches**

Create `tests/dev_flow_gate_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/dev-flow-gate.sh"
source "$SCRIPT_DIR/../lib/state.sh"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# 1. No state file -> exit 0, no output
rm -f "$DEV_FLOW_STATE_FILE"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no output when no state file exists"

# 2. Mid-cycle phase (e.g. build) -> block decision, blocks incremented
state_init "add-user-auth" "openspec"
state_set_phase "build"
output="$("$GATE")"
echo "$output" | grep -q '"decision":"block"' || fail "expected block decision for phase=build"
[ "$(state_get blocks)" = "1" ] || fail "blocks should be incremented to 1 after one block"

# 3. phase=await-approval -> allow, no output, blocks untouched
state_set_phase "await-approval"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no block output for await-approval"
[ "$(state_get blocks)" = "1" ] || fail "blocks should stay at 1 (await-approval does not increment)"

# 4. phase=done -> allow, no output
state_set_phase "done"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no block output for done"

# 5. phase=paused -> allow, no output
state_set_phase "paused"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no block output for paused"

# 6. blocks at cap (40) -> allow even mid-cycle
state_set_phase "build"
tmp="$(mktemp)"
jq '.blocks = 40' "$DEV_FLOW_STATE_FILE" > "$tmp" && mv "$tmp" "$DEV_FLOW_STATE_FILE"
output="$("$GATE")"
[ -z "$output" ] || fail "expected no block output once blocks cap (40) reached"

echo "PASS: hooks/dev-flow-gate.sh"
```

Make it executable:

```bash
chmod +x tests/dev_flow_gate_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/dev_flow_gate_test.sh`
Expected: FAIL — `bash: .../hooks/dev-flow-gate.sh: No such file or directory`

- [ ] **Step 3: Write minimal implementation**

Create `hooks/dev-flow-gate.sh`:

```bash
#!/usr/bin/env bash
# hooks/dev-flow-gate.sh - Stop hook that forces dev-flow to continue
# until the cycle reaches done/paused/await-approval, or the 40-block
# safety cap is hit.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/state.sh"

BLOCK_CAP=40

if ! state_exists; then
  exit 0
fi

phase="$(state_get phase)"
case "$phase" in
  done|paused|await-approval)
    exit 0
    ;;
esac

blocks="$(state_get blocks)"
if [ "$blocks" -ge "$BLOCK_CAP" ]; then
  exit 0
fi

state_increment_blocks

cat <<EOF
{"decision":"block","reason":"dev-flow 进行中(当前阶段: $phase)。请继续执行下一阶段并更新状态文件。若用户已明确要求停止,请先执行 /dev-flow:stop。"}
EOF
```

Make it executable:

```bash
chmod +x hooks/dev-flow-gate.sh
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/dev_flow_gate_test.sh`
Expected: `PASS: hooks/dev-flow-gate.sh`

- [ ] **Step 5: Commit**

```bash
git add hooks/dev-flow-gate.sh tests/dev_flow_gate_test.sh
git commit -m "feat: add dev-flow-gate Stop hook enforcing forced continuation"
```

---

### Task 3: `skills/dev-flow/SKILL.md` — the auto-triggered engine

**Files:**
- Create: `skills/dev-flow/SKILL.md`
- Test: `tests/skill_structure_test.sh`

**Interfaces:**
- Consumes: `lib/state.sh` schema and function names from Task 1 (documented in the skill's own instructions, since the skill is prompt text executed by Claude, not a script that sources bash), `hooks/dev-flow-gate.sh` contract from Task 2 (must be registered as a Stop hook — registration itself is out of scope for this capability, owned by `installer`)
- Produces: the single auto-triggered skill; used later by `cli-commands` (`/dev-flow:start` etc. read/write the same state file) and referenced by `spec-tool-adapter` (`references/spec-tool-<value>.md` files this skill will look for) and `gstack-bridge` (`/gs:ship` command this skill invokes)

- [ ] **Step 1: Write the failing structural test**

Create `tests/skill_structure_test.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x tests/skill_structure_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/skill_structure_test.sh`
Expected: FAIL — `SKILL.md does not exist`

- [ ] **Step 3: Write the SKILL.md content**

Create `skills/dev-flow/SKILL.md`:

```markdown
---
name: dev-flow
description: 本项目所有开发任务的唯一自动触发入口。用户提出任何代码相关
  需求(修 bug、加功能、重构、改 UI、性能优化),或调用 /dev-flow:start
  时使用。驱动 propose → await-approval → plan → build → verify → ship
  → archive → done 全流程自动推进,阶段之间不停顿、不询问,直到完成或
  用户明确要求停止。这是本项目里唯一允许自动触发的技能——所有其它
  CodeFlow 能力(gs/* 等)都是普通 command,不会自动触发,不会与本技能
  抢触发权。
---

# dev-flow: 自动推进的开发工作流引擎

## 状态文件

所有运行状态存在 `.claude/dev-flow-state.json`,字段:`feature`、
`phase`、`blocks`、`spec_tool`。通过 `lib/state.sh` 提供的函数读写,
不要直接用 jq/cat 手改这个文件:

- `state_init <feature> <spec_tool>` — 开始新一轮循环时调用一次
- `state_get <field>` — 读取字段
- `state_set_phase <phase>` — 切换到下一阶段时调用
- `state_increment_blocks` — 由 Stop hook 自己调用,skill 不需要手动调

## 阶段序列(固定,不可跳过或重排)

```
propose → await-approval → plan → build → verify → ship → archive → done
```

## 启动新一轮循环

收到开发需求(或用户执行 `/dev-flow:start <功能名>`)时:

1. 读取 `.claude/dev-flow.config.json` 的 `spec_tool` 字段(缺省视为
   `"openspec"`)
2. 执行 `state_init "<功能名>" "<spec_tool>"`,此时 `phase` 自动为
   `propose`
3. 进入 propose 阶段(见下)

## 各阶段动作

### propose
读取当前 `spec_tool`,查找 `skills/dev-flow/references/spec-tool-<spec_tool>.md`。

- **文件存在**:按该文件里 "propose 阶段做什么" 一节的指示生成 spec。
  完成后执行 `state_set_phase "await-approval"`,展示 spec 摘要,结束
  这一轮回复(Stop hook 在 `await-approval` 阶段会放行,不会强制续跑)。
- **文件不存在**:不要猜测或跳过。执行 `state_set_phase "paused"`,
  向用户说明 `spec_tool` 配置的值没有对应的 reference 文件,请用户
  修正 `.claude/dev-flow.config.json` 后再继续。

### await-approval
等待用户批准(用户说"批准/继续/ok"等)。收到批准后执行
`state_set_phase "plan"`,进入 plan 阶段。用户若要求修改 spec,留在
`await-approval`,不要自行推进。

### plan
基于 propose 阶段产出的 spec 目录,使用 Superpowers 的 writing-plans
技能生成实施计划。完成后执行 `state_set_phase "build"`。

### build
按 writing-plans 产出的计划,使用 Superpowers 的 TDD 技能逐任务执行
(子代理隔离)。全部任务完成后执行 `state_set_phase "verify"`。

### verify
1. 读取 `.claude/dev-flow.config.json` 的 `gate_command` 字段:
   - 非空:执行该 shell 命令,必须成功(exit 0)才能继续;失败则修复
     后重试,不要跳过。
   - 为空或不存在:跳过这一步。
2. 读取 `codex_review` 字段(布尔):
   - 为 `true`:调用 `/codex:review --base main`,处理 BLOCKED 反馈后
     重跑,直至通过。
   - 为 `false` 或不存在:跳过这一步。
3. 两步都通过后执行 `state_set_phase "ship"`。

### ship
调用 `/gs:ship`(只按命令名调用,不关心其内部实现)。成功后执行
`state_set_phase "archive"`。

### archive
再次查找 `skills/dev-flow/references/spec-tool-<spec_tool>.md`,按该
文件里 "archive 阶段做什么" 一节的指示归档 spec。完成后执行
`state_set_phase "done"`。

## 用户要求停止

用户在任意阶段说"停止/暂停/stop"时,调用 `/dev-flow:stop`(会删除状态
文件)并汇报当前完成到哪一步,然后结束回复。除此之外,以及除
`await-approval` 阶段外,不要主动停下来"汇报进度"或"询问是否继续"——
Stop hook 会把这类提前结束强制拦截推回。
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/skill_structure_test.sh`
Expected: `PASS: skills/dev-flow/SKILL.md structure`

- [ ] **Step 5: Commit**

```bash
git add skills/dev-flow/SKILL.md tests/skill_structure_test.sh
git commit -m "feat: add dev-flow SKILL.md driving the propose-to-done cycle"
```

---

### Task 4: End-to-end dry-run of the full cycle

**Files:**
- Create: `tests/e2e_cycle_test.sh`

**Interfaces:**
- Consumes: `lib/state.sh` (Task 1) and `hooks/dev-flow-gate.sh` (Task 2) directly; does not invoke Claude or any real `/opsx:*`, `/gs:*`, or `/codex:review` command — this test proves the state machine's own transition/hook contract, not the skill's prompt behavior (which cannot be unit-tested outside a real Claude session)

- [ ] **Step 1: Write the failing end-to-end test**

Create `tests/e2e_cycle_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="$SCRIPT_DIR/../hooks/dev-flow-gate.sh"
source "$SCRIPT_DIR/../lib/state.sh"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

state_init "add-user-auth" "openspec"

# Phases where the gate must force continuation (blocks increment each time)
BLOCKING_PHASES=(propose plan build verify ship archive)
expected_blocks=0
for phase in "${BLOCKING_PHASES[@]}"; do
  state_set_phase "$phase"
  output="$("$GATE")"
  echo "$output" | grep -q '"decision":"block"' || fail "expected block at phase=$phase"
  expected_blocks=$((expected_blocks + 1))
  [ "$(state_get blocks)" = "$expected_blocks" ] || fail "blocks should be $expected_blocks after phase=$phase"
done

# await-approval must allow without incrementing blocks
state_set_phase "await-approval"
output="$("$GATE")"
[ -z "$output" ] || fail "expected allow (no output) at await-approval"
[ "$(state_get blocks)" = "$expected_blocks" ] || fail "blocks must not increment at await-approval"

# done must allow without incrementing blocks
state_set_phase "done"
output="$("$GATE")"
[ -z "$output" ] || fail "expected allow (no output) at done"
[ "$(state_get blocks)" = "$expected_blocks" ] || fail "blocks must not increment at done"

# Safety cap: force blocks to 39, one more block phase should hit 40 and still block,
# the call after that (at 40) must allow.
state_set_phase "build"
tmp="$(mktemp)"
jq '.blocks = 39' "$DEV_FLOW_STATE_FILE" > "$tmp" && mv "$tmp" "$DEV_FLOW_STATE_FILE"
output="$("$GATE")"
echo "$output" | grep -q '"decision":"block"' || fail "expected block at blocks=39 -> 40"
[ "$(state_get blocks)" = "40" ] || fail "blocks should reach exactly 40"

output="$("$GATE")"
[ -z "$output" ] || fail "expected allow once blocks cap (40) is reached, got: $output"

echo "PASS: full propose-to-done cycle honors phase sequence, await-approval pause, and 40-block safety cap"
```

Make it executable:

```bash
chmod +x tests/e2e_cycle_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/e2e_cycle_test.sh`
Expected: FAIL only if Task 1/2 are incomplete. If Tasks 1–3 above are already done in order, this test should actually PASS immediately — in that case, skip to Step 3 as a verification run rather than a red step, and note in the commit message that this is a verification-only addition.

- [ ] **Step 3: Run test to verify it passes**

Run: `bash tests/e2e_cycle_test.sh`
Expected: `PASS: full propose-to-done cycle honors phase sequence, await-approval pause, and 40-block safety cap`

- [ ] **Step 4: Run the full test suite together**

Run:
```bash
for t in tests/lib_state_test.sh tests/dev_flow_gate_test.sh tests/skill_structure_test.sh tests/e2e_cycle_test.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```
Expected: all four `PASS:` lines printed, no `FAIL:` lines, exit code 0

- [ ] **Step 5: Commit**

```bash
git add tests/e2e_cycle_test.sh
git commit -m "test: add end-to-end dry run covering full dev-flow phase sequence"
```

---

## Plan Self-Review

**Spec coverage** (against `openspec/changes/orchestration-engine/specs/orchestration-engine/spec.md`):
- Single auto-triggered entry point → Task 3 Step 3 frontmatter + Task 3 test asserts uniqueness intent (only one `name: dev-flow` skill in this repo; cross-capability enforcement is structural — no other capability in this plan defines a skill)
- Run-level state file → Task 1
- Fixed phase sequence → Task 3 SKILL.md phase order + Task 4 e2e test
- Forced continuation via Stop hook → Task 2
- Human approval checkpoint → Task 3 (`await-approval` handling) + Task 2/4 tests (hook allows at that phase)
- Safety cap on forced continuations → Task 2 Step 1 case 6 + Task 4 Step 1 cap test
- Project config fields read by engine → Task 3 SKILL.md verify-phase instructions (`gate_command`, `codex_review`) + structure test
- Delegated propose/archive by naming convention → Task 3 SKILL.md propose/archive sections + missing-reference-file pause + structure test
- Delegated ship by command-name convention → Task 3 SKILL.md ship section + structure test
All 9 requirements have a corresponding task. No gaps found.

**Placeholder scan:** No TBD/TODO, no "add appropriate handling" phrasing, no "similar to Task N" shortcuts — every step has literal file contents.

**Type/name consistency check:** `state_file`, `state_exists`, `state_init(feature, spec_tool)`, `state_get(field)`, `state_set_phase(phase)`, `state_increment_blocks` are used with identical names and argument order across Task 1 (definition), Task 2 (hook consumption), Task 3 (SKILL.md documentation), and Task 4 (e2e test) — verified consistent.
