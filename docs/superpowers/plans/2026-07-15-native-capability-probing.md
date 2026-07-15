# Native Capability Probing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install dev-flow safely across Claude Code, Codex, and Cursor, enabling native integration only when a verified local capability exists.

**Architecture:** `install.sh` reads `config/client-capabilities.json`, migrates legacy state, and writes thin CodeFlow-owned adapters. Canonical workflow remains under `skills/` and `commands/`; every target uses the same `.codeflow/` state.

**Tech Stack:** Bash, jq, JSON, Markdown, shell tests.

## Global Constraints

- Default state/config paths are `.codeflow/dev-flow-state.json` and `.codeflow/dev-flow.config.json`.
- A legacy and canonical file conflict must stop installation without overwriting either file.
- Claude installs one merged Stop hook; Codex/Cursor only enable native integration after a probe succeeds.
- Dry runs create no files and every unsupported capability is reported plainly.

---

### Task 1: Neutral state migration

**Files:** Modify `lib/state.sh`, `install.sh`; create `tests/installer_migration_test.sh`.

- [x] **Step 1: Write failing migration tests**

```bash
mkdir -p "$tmp/.claude"
printf '{"feature":"x","phase":"build","blocks":0}\n' > "$tmp/.claude/dev-flow-state.json"
(cd "$tmp" && "$INSTALLER" claude)
test -f "$tmp/.codeflow/dev-flow-state.json"
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash tests/installer_migration_test.sh`

Expected: FAIL because no migration is implemented.

- [x] **Step 3: Implement migration**

Change `state_file()` to `echo "${DEV_FLOW_STATE_FILE:-.codeflow/dev-flow-state.json}"`. Add `migrate_legacy_file legacy canonical label` to `install.sh`; move only when legacy exists alone, report both documented conflict messages otherwise.

- [x] **Step 4: Run tests**

Run: `bash tests/installer_migration_test.sh && bash tests/lib_state_test.sh`

Expected: both PASS.

- [x] **Step 5: Commit**

```bash
git add install.sh lib/state.sh tests/installer_migration_test.sh
git commit -m "feat: migrate dev-flow state to neutral location"
```

### Task 2: Capability reporting and owned writes

**Files:** Modify `install.sh`; create `tests/installer_capability_test.sh`.

- [x] **Step 1: Write failing capability tests**

```bash
output="$(cd "$tmp" && "$INSTALLER" codex)"
echo "$output" | grep -q 'codex.continuation_gate=unavailable'
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash tests/installer_capability_test.sh`

Expected: FAIL because statuses are not reported.

- [x] **Step 3: Implement capability helpers**

Add `report_capability target capability status` and `write_owned_file path source`; read `config/client-capabilities.json` through jq and print `enabled`, `unavailable`, or `unsupported-version`.

- [x] **Step 4: Run tests**

Run: `bash tests/client_capabilities_test.sh && bash tests/installer_capability_test.sh`

Expected: both PASS.

- [x] **Step 5: Commit**

```bash
git add install.sh tests/installer_capability_test.sh
git commit -m "feat: report client integration capabilities"
```

### Task 3: Claude adapter and continuation gate

**Files:** Modify `install.sh`; create `tests/claude_adapter_test.sh`.

- [x] **Step 1: Write failing adapter test**

```bash
(cd "$tmp" && "$INSTALLER" claude)
test -f "$tmp/.claude/skills/dev-flow/SKILL.md"
test -f "$tmp/.claude/commands/dev-flow/start.md"
jq -e '.hooks.Stop | length == 1' "$tmp/.claude/settings.json"
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash tests/claude_adapter_test.sh`

Expected: FAIL because Claude adapter files do not exist.

- [x] **Step 3: Implement Claude installation**

Copy canonical skill, references, commands, and `hooks/dev-flow-gate.sh`; merge one identifiable CodeFlow command hook into `.claude/settings.json` with jq while retaining unrelated settings and avoiding duplicates.

- [x] **Step 4: Run tests**

Run: `bash tests/claude_adapter_test.sh && bash tests/dev_flow_gate_test.sh`

Expected: both PASS.

- [x] **Step 5: Commit**

```bash
git add install.sh tests/claude_adapter_test.sh
git commit -m "feat: install Claude dev-flow adapter and gate"
```

### Task 4: Codex and Cursor adapters

**Files:** Modify `install.sh`; create `tests/codex_cursor_adapter_test.sh`.

- [x] **Step 1: Write failing target-isolation tests**

```bash
(cd "$tmp" && "$INSTALLER" cursor)
test -f "$tmp/.cursor/skills/dev-flow/SKILL.md"
test -f "$tmp/.cursor/commands/dev-flow-start.md"
test ! -e "$tmp/.claude/settings.json"
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash tests/codex_cursor_adapter_test.sh`

Expected: FAIL because target adapters do not exist.

- [x] **Step 3: Implement prompt-guided adapters**

Install Codex skill with explicit start/stop/status/update guidance. Install Cursor skill plus four Markdown commands. Enable optional native command/hook files only when a verified probe passes; otherwise report the degraded capability status.

- [x] **Step 4: Run tests**

Run: `bash tests/codex_cursor_adapter_test.sh`

Expected: PASS with no cross-target files.

- [x] **Step 5: Commit**

```bash
git add install.sh tests/codex_cursor_adapter_test.sh
git commit -m "feat: install Codex and Cursor dev-flow adapters"
```

### Task 5: Target-aware update and full regression

**Files:** Modify `commands/dev-flow/update.md`, `tests/cli_update_test.sh`; create `tests/installer_integration_test.sh`.

- [x] **Step 1: Write failing update test**

```bash
output="$(cd "$tmp" && eval "$SNIPPET")"
echo "$output" | grep -q 'Selected target: cursor'
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash tests/cli_update_test.sh`

Expected: FAIL because update has no owning client target.

- [x] **Step 3: Implement target-aware update**

Generate owned update wrappers that run `bash install.sh <target>` and retain the existing absent-installer message. Add integration coverage for first install, reinstallation, dry-run, migration conflicts, and capability reports.

- [x] **Step 4: Run the full suite**

```bash
for t in tests/*_test.sh; do bash "$t" || exit 1; done
```

Expected: every test prints `PASS:`.

- [x] **Step 5: Commit**

```bash
git add commands/dev-flow/update.md tests/cli_update_test.sh tests/installer_integration_test.sh
git commit -m "feat: refresh dev-flow adapters by target"
```

## Self-Review

- Tasks 1–5 cover neutral state, migration conflicts, capability probing, all adapters, Claude enforcement, Codex/Cursor degradation, updates, and regression tests.
- The plan contains no unspecified implementation placeholders.
- Target names and capability statuses are consistent with `config/client-capabilities.json`.
