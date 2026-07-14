# CLI Commands Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the four `/dev-flow:*` control commands (`start`, `stop`, `status`, `update`) that `orchestration-engine`'s SKILL.md already assumes exist, giving users an explicit way to start, stop, inspect, and update a dev-flow cycle.

**Architecture:** Four Markdown command files under `commands/dev-flow/`, following this repo's existing command convention (frontmatter with `name`/`description`/`category`/`tags`, matching `.claude/commands/opsx/propose.md`). `start.md` delegates to the `dev-flow` skill via the Skill tool (no duplicated logic). `stop.md`, `status.md`, and `update.md` each embed one exact, literal bash snippet in a fenced code block that Claude is instructed to run verbatim — this makes them independently testable with real script execution (extract the fenced snippet, run it against a real temp state file / temp directory), not just structural grep.

**Tech Stack:** Markdown (command prompt files with embedded bash), bash test scripts (some structural grep, some real extraction-and-execution of the embedded snippet).

## Global Constraints

- All four files live under `commands/dev-flow/` — never under any `skills/` directory. That placement (not the presence or absence of a `description:` field) is what keeps them from being semantically auto-triggered; `dev-flow` (`skills/dev-flow/SKILL.md`) remains the sole auto-triggered skill in the project.
- A `description:` frontmatter field on each of these four files is expected and conventional (matches `.claude/commands/opsx/propose.md`) — do not omit it, and do not treat its presence as a defect.
- `start.md` must not reimplement `state_init`/phase-sequencing logic — it delegates to the `dev-flow` skill via the Skill tool.
- `stop.md` reads `feature`/`phase` from the state file BEFORE deleting it (order matters — reading after deletion would fail).
- `status.md` must never modify the state file.
- `update.md` must check for `install.sh`'s existence before running it, and must report plainly (not guess or attempt an alternative) if it's absent.
- All state-file operations go through `lib/state.sh` (from `orchestration-engine`, already shipped) — never touch `.claude/dev-flow-state.json` directly.

---

### Task 1: `commands/dev-flow/start.md`

**Files:**
- Create: `commands/dev-flow/start.md`
- Test: `tests/cli_start_test.sh`

**Interfaces:**
- Consumes: the `dev-flow` skill (`skills/dev-flow/SKILL.md`, already shipped) via the Skill tool — this file does not call any `lib/state.sh` function directly
- Produces: nothing consumed by later tasks in this plan (this is the last file in the dependency chain for `cli-commands`)

- [ ] **Step 1: Write the failing structural test**

Create `tests/cli_start_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/dev-flow/start.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "start.md does not exist"
grep -q '^description:' "$FILE" || fail "missing description: frontmatter field"
grep -q '\$ARGUMENTS' "$FILE" || fail "does not reference \$ARGUMENTS"
grep -qi 'dev-flow' "$FILE" || fail "does not mention the dev-flow skill"
grep -qi 'Skill tool' "$FILE" || fail "does not instruct using the Skill tool to invoke it"

if grep -qi 'state_init' "$FILE"; then
  fail "must not duplicate state_init logic directly (should delegate to the dev-flow skill instead)"
fi

echo "PASS: commands/dev-flow/start.md structure"
```

Make it executable:

```bash
chmod +x tests/cli_start_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cli_start_test.sh`
Expected: FAIL — `start.md does not exist`

- [ ] **Step 3: Write the command file**

Create `commands/dev-flow/start.md`:

```markdown
---
name: "Dev Flow: Start"
description: Start a new dev-flow development cycle for a named feature
category: Workflow
tags: [workflow, dev-flow]
---

Start a new dev-flow development cycle.

**Input**: The argument after `/dev-flow:start` is the feature name
(kebab-case), e.g. `/dev-flow:start add-user-auth`. Use `$ARGUMENTS` as
the feature name.

Use the Skill tool to invoke the `dev-flow` skill, framing this as a
request to start a new development cycle for the feature named in
`$ARGUMENTS`. Do not perform state initialization or phase-sequencing
yourself here — `skills/dev-flow/SKILL.md` already fully specifies what
happens when a new cycle starts (`state_init`, entering the `propose`
phase, and so on). This command's only job is to trigger that skill
with the right feature name.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cli_start_test.sh`
Expected: `PASS: commands/dev-flow/start.md structure`

- [ ] **Step 5: Commit**

```bash
git add commands/dev-flow/start.md tests/cli_start_test.sh
git commit -m "feat: add /dev-flow:start command delegating to the dev-flow skill"
```

---

### Task 2: `commands/dev-flow/stop.md`

**Files:**
- Create: `commands/dev-flow/stop.md`
- Test: `tests/cli_stop_test.sh`

**Interfaces:**
- Consumes: `lib/state.sh` functions (`state_exists`, `state_get`, `state_file`) from `orchestration-engine`, already shipped
- Produces: an embedded bash snippet (inside a single ` ```bash ... ``` ` fenced block) that the test extracts and runs directly — this is the contract the test relies on, so the snippet must appear exactly once, fenced with ` ```bash ` and a closing ` ``` ` on their own lines

- [ ] **Step 1: Write the failing test**

Create `tests/cli_stop_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/dev-flow/stop.md"
STATE_LIB="$SCRIPT_DIR/../lib/state.sh"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "stop.md does not exist"

# Extract the single ```bash ... ``` fenced snippet
SNIPPET="$(sed -n '/^```bash$/,/^```$/p' "$FILE" | sed '1d;$d')"
[ -n "$SNIPPET" ] || fail "no fenced bash snippet found in stop.md"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Case 1: active cycle exists ---
source "$STATE_LIB"
state_init "add-user-auth" "openspec"
state_set_phase "build"

output="$(cd "$SCRIPT_DIR/.." && eval "$SNIPPET")"
echo "$output" | grep -q "add-user-auth" || fail "stop output does not mention the feature name"
echo "$output" | grep -q "build" || fail "stop output does not mention the phase reached"
[ -f "$DEV_FLOW_STATE_FILE" ] && fail "state file should be deleted after stop"

# --- Case 2: no active cycle ---
rm -f "$DEV_FLOW_STATE_FILE"
output="$(cd "$SCRIPT_DIR/.." && eval "$SNIPPET")"
echo "$output" | grep -qi "no active" || fail "expected a 'no active cycle' message when nothing to stop"

echo "PASS: commands/dev-flow/stop.md behavior"
```

Make it executable:

```bash
chmod +x tests/cli_stop_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cli_stop_test.sh`
Expected: FAIL — `stop.md does not exist`

- [ ] **Step 3: Write the command file**

Create `commands/dev-flow/stop.md`:

```markdown
---
name: "Dev Flow: Stop"
description: Stop the current dev-flow cycle and report how far it got
category: Workflow
tags: [workflow, dev-flow]
---

Stop the current dev-flow cycle, if one is running, and report how far
it got. Run this exact shell command from the project root, then report
its output to the user verbatim — do not paraphrase or summarize it
differently:

```bash
source lib/state.sh
if state_exists; then
  feature="$(state_get feature)"
  phase="$(state_get phase)"
  rm -f "$(state_file)"
  echo "Stopped cycle for feature '${feature}' at phase '${phase}'."
else
  echo "No active dev-flow cycle to stop."
fi
```
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cli_stop_test.sh`
Expected: `PASS: commands/dev-flow/stop.md behavior`

- [ ] **Step 5: Commit**

```bash
git add commands/dev-flow/stop.md tests/cli_stop_test.sh
git commit -m "feat: add /dev-flow:stop command reading progress before deleting state"
```

---

### Task 3: `commands/dev-flow/status.md`

**Files:**
- Create: `commands/dev-flow/status.md`
- Test: `tests/cli_status_test.sh`

**Interfaces:**
- Consumes: `lib/state.sh` functions (`state_exists`, `state_get`) — read-only, never calls `state_set_phase`/`state_increment_blocks`/deletes anything
- Produces: an embedded bash snippet, same extraction contract as Task 2

- [ ] **Step 1: Write the failing test**

Create `tests/cli_status_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/dev-flow/status.md"
STATE_LIB="$SCRIPT_DIR/../lib/state.sh"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "status.md does not exist"

SNIPPET="$(sed -n '/^```bash$/,/^```$/p' "$FILE" | sed '1d;$d')"
[ -n "$SNIPPET" ] || fail "no fenced bash snippet found in status.md"

TMPDIR_TEST="$(mktemp -d)"
export DEV_FLOW_STATE_FILE="$TMPDIR_TEST/dev-flow-state.json"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Case 1: active cycle exists ---
source "$STATE_LIB"
state_init "add-user-auth" "openspec"
state_set_phase "verify"
state_increment_blocks
before_checksum="$(md5sum "$DEV_FLOW_STATE_FILE" 2>/dev/null || shasum "$DEV_FLOW_STATE_FILE")"

output="$(cd "$SCRIPT_DIR/.." && eval "$SNIPPET")"
echo "$output" | grep -q "add-user-auth" || fail "status output does not mention the feature"
echo "$output" | grep -q "verify" || fail "status output does not mention the phase"
echo "$output" | grep -q "1" || fail "status output does not mention the blocks count"

after_checksum="$(md5sum "$DEV_FLOW_STATE_FILE" 2>/dev/null || shasum "$DEV_FLOW_STATE_FILE")"
[ "$before_checksum" = "$after_checksum" ] || fail "status must not modify the state file"

# --- Case 2: no active cycle ---
rm -f "$DEV_FLOW_STATE_FILE"
output="$(cd "$SCRIPT_DIR/.." && eval "$SNIPPET")"
echo "$output" | grep -qi "no active" || fail "expected a 'no active cycle' message"

echo "PASS: commands/dev-flow/status.md behavior"
```

Make it executable:

```bash
chmod +x tests/cli_status_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cli_status_test.sh`
Expected: FAIL — `status.md does not exist`

- [ ] **Step 3: Write the command file**

Create `commands/dev-flow/status.md`:

```markdown
---
name: "Dev Flow: Status"
description: Report the current dev-flow cycle's phase and progress
category: Workflow
tags: [workflow, dev-flow]
---

Report the current dev-flow cycle's state without modifying anything.
Run this exact shell command from the project root, then report its
output to the user verbatim — do not paraphrase or summarize it
differently:

```bash
source lib/state.sh
if state_exists; then
  feature="$(state_get feature)"
  phase="$(state_get phase)"
  blocks="$(state_get blocks)"
  echo "feature=${feature} phase=${phase} blocks=${blocks}"
else
  echo "No active dev-flow cycle."
fi
```
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cli_status_test.sh`
Expected: `PASS: commands/dev-flow/status.md behavior`

- [ ] **Step 5: Commit**

```bash
git add commands/dev-flow/status.md tests/cli_status_test.sh
git commit -m "feat: add /dev-flow:status command for read-only cycle inspection"
```

---

### Task 4: `commands/dev-flow/update.md`

**Files:**
- Create: `commands/dev-flow/update.md`
- Test: `tests/cli_update_test.sh`

**Interfaces:**
- Consumes: `install.sh` at the project root (owned by the not-yet-built `installer` capability) — checks for its existence, does not assume its contents or invent a fallback mechanism
- Produces: an embedded bash snippet, same extraction contract as Tasks 2-3

- [ ] **Step 1: Write the failing test**

Create `tests/cli_update_test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$SCRIPT_DIR/../commands/dev-flow/update.md"

fail() { echo "FAIL: $1"; exit 1; }

[ -f "$FILE" ] || fail "update.md does not exist"

SNIPPET="$(sed -n '/^```bash$/,/^```$/p' "$FILE" | sed '1d;$d')"
[ -n "$SNIPPET" ] || fail "no fenced bash snippet found in update.md"

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# --- Case 1: install.sh present ---
cat > "$TMPDIR_TEST/install.sh" <<'INSTALLER'
#!/usr/bin/env bash
echo "install.sh ran"
INSTALLER
chmod +x "$TMPDIR_TEST/install.sh"

output="$(cd "$TMPDIR_TEST" && eval "$SNIPPET")"
echo "$output" | grep -q "install.sh ran" || fail "expected install.sh to actually run when present"

# --- Case 2: install.sh absent ---
rm -f "$TMPDIR_TEST/install.sh"
output="$(cd "$TMPDIR_TEST" && eval "$SNIPPET")"
echo "$output" | grep -qi "not available" || fail "expected a plain 'installer not available' message when install.sh is missing"

echo "PASS: commands/dev-flow/update.md behavior"
```

Make it executable:

```bash
chmod +x tests/cli_update_test.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/cli_update_test.sh`
Expected: FAIL — `update.md does not exist`

- [ ] **Step 3: Write the command file**

Create `commands/dev-flow/update.md`:

```markdown
---
name: "Dev Flow: Update"
description: Refresh this project's dev-flow files via the installer
category: Workflow
tags: [workflow, dev-flow]
---

Refresh this project's dev-flow skill/hook/reference files to the
latest version, if an installer is available. Run this exact shell
command from the project root, then report its output to the user
verbatim — do not paraphrase or summarize it differently:

```bash
if [ -f install.sh ]; then
  bash install.sh
else
  echo "installer not available yet in this project (install.sh not found) - no action taken."
fi
```
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/cli_update_test.sh`
Expected: `PASS: commands/dev-flow/update.md behavior`

- [ ] **Step 5: Commit**

```bash
git add commands/dev-flow/update.md tests/cli_update_test.sh
git commit -m "feat: add /dev-flow:update command with graceful degradation"
```

---

### Task 5: Cross-cutting placement check and full suite verification

**Files:**
- Create: `tests/cli_commands_no_autotrigger_test.sh`

**Interfaces:**
- Consumes: the four command files from Tasks 1-4, checked by path only (no execution)

- [ ] **Step 1: Write the test**

Create `tests/cli_commands_no_autotrigger_test.sh`:

```bash
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
```

Make it executable:

```bash
chmod +x tests/cli_commands_no_autotrigger_test.sh
```

- [ ] **Step 2: Run test to verify it passes**

This test should pass immediately once Tasks 1-4 are committed correctly — run it once as a verification gate:

Run: `bash tests/cli_commands_no_autotrigger_test.sh`
Expected: `PASS: cli-commands stay under commands/dev-flow/, dev-flow remains the sole auto-triggered skill`

- [ ] **Step 3: Run the full test suite together (all cli-commands tests plus the entire existing suite, to confirm no regressions)**

Run:
```bash
for t in tests/lib_state_test.sh tests/dev_flow_gate_test.sh tests/skill_structure_test.sh tests/e2e_cycle_test.sh \
         tests/spec_tool_openspec_test.sh tests/spec_tool_speckit_test.sh tests/spec_tool_adapter_consistency_test.sh \
         tests/cli_start_test.sh tests/cli_stop_test.sh tests/cli_status_test.sh tests/cli_update_test.sh \
         tests/cli_commands_no_autotrigger_test.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```
Expected: twelve `PASS:` lines, no `FAIL:` lines, exit code 0

- [ ] **Step 4: Commit**

```bash
git add tests/cli_commands_no_autotrigger_test.sh
git commit -m "test: add placement check confirming dev-flow remains sole auto-triggered skill"
```

---

## Plan Self-Review

**Spec coverage** (against `openspec/changes/cli-commands/specs/cli-commands/spec.md`):
- `/dev-flow:start` delegates to the dev-flow skill → Task 1
- `/dev-flow:stop` reads progress before deleting state → Task 2 (both scenarios: active cycle, no active cycle)
- `/dev-flow:status` reports state without modifying it → Task 3 (both scenarios, plus a checksum-based no-mutation check)
- `/dev-flow:update` degrades gracefully → Task 4 (both scenarios)
- Commands never carry skill-style auto-trigger behavior (corrected: placement, not field presence) → Task 5
All 5 requirements have a corresponding task and real test coverage. No gaps found.

**Placeholder scan:** No TBD/TODO, no vague "handle appropriately" phrasing — every step has literal file contents and literal test code.

**Type/name consistency check:** `lib/state.sh` function names (`state_exists`, `state_get`, `state_set_phase`, `state_increment_blocks`, `state_file`) match their Task 1 (orchestration-engine) definitions exactly, verified against the actual shipped file before writing this plan. The fenced-snippet extraction pattern (`sed -n '/^```bash$/,/^```$/p' | sed '1d;$d'`) is identical across Tasks 2-4's tests, and each corresponding command file's snippet is fenced exactly once with matching markers, so the extraction contract holds for all three.
