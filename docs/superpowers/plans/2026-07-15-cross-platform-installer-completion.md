# Cross-Platform Installer Completion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete and verify the cross-platform dev-flow installer for Claude Code, Codex, and Cursor.

**Architecture:** Keep `install.sh` as the only deployment entry point. It uses canonical sources, the capability matrix, `.codeflow` state migration, and thin per-client adapters; unverified native mechanisms remain explicitly prompt-guided.

**Tech Stack:** Bash, jq, JSON, Markdown, shell tests.

## Global Constraints

- Tests run only in `mktemp` fixtures and never install into this repository.
- `.codeflow/` is the default state/config owner; legacy conflicts abort without writes.
- Claude gets a merged Stop hook; Codex/Cursor report unavailable native hooks unless a verified probe succeeds.
- Installer writes only CodeFlow-owned files and dry run never writes.

---

### Task 1: Lock down migration and installer isolation

**Files:** Modify `install.sh`, `lib/state.sh`; create `tests/installer_migration_test.sh`.

- [ ] **Step 1: Add failing fixture tests**

```bash
legacy="$tmp/.claude/dev-flow-state.json"
canonical="$tmp/.codeflow/dev-flow-state.json"
mkdir -p "$(dirname "$legacy")"; printf '{"phase":"build"}\n' > "$legacy"
(cd "$tmp" && "$INSTALLER" claude)
test -f "$canonical" && test ! -f "$legacy"
```

- [ ] **Step 2: Verify red**

Run: `bash tests/installer_migration_test.sh`

Expected: FAIL before migration behavior is fully covered.

- [ ] **Step 3: Implement and verify**

Implement independent state/config moves before target adapter installation. The loop must process both `state` and `config`: it must not return after moving state, and it must preserve a successfully moved state if the later config migration reports a conflict. Add a fixture assertion that both canonical files exist after a successful migration, then add separate conflict fixtures for state and config.

Run: `bash tests/installer_migration_test.sh && bash tests/installer_target_selection_test.sh && bash tests/lib_state_test.sh`

Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add install.sh lib/state.sh tests/installer_migration_test.sh tests/installer_target_selection_test.sh
git commit -m "feat: isolate installer and migrate dev-flow state"
```

### Task 2: Install Claude Code safely

**Files:** Modify `install.sh`; create `tests/claude_adapter_test.sh`.

- [ ] **Step 1: Add failing Claude fixture test**

```bash
(cd "$tmp" && "$INSTALLER" claude)
test -f "$tmp/.claude/skills/dev-flow/SKILL.md"
test -f "$tmp/.claude/commands/dev-flow/start.md"
jq -e '.hooks.Stop | length == 1' "$tmp/.claude/settings.json"
```

- [ ] **Step 2: Verify red then implement**

Run: `bash tests/claude_adapter_test.sh`

Expected: FAIL before complete Claude adapter behavior.

Copy owned sources and merge exactly one `bash hooks/dev-flow-gate.sh` hook while preserving unrelated settings.

- [ ] **Step 3: Verify and commit**

Run: `bash tests/claude_adapter_test.sh && bash tests/dev_flow_gate_test.sh`

Expected: both PASS.

```bash
git add install.sh tests/claude_adapter_test.sh
git commit -m "feat: install Claude dev-flow adapter"
```

### Task 3: Install Codex and Cursor with truthful fallback

**Files:** Modify `install.sh`; create `tests/codex_cursor_adapter_test.sh`.

- [ ] **Step 1: Add failing target-isolation tests**

```bash
(cd "$tmp" && "$INSTALLER" cursor)
test -f "$tmp/.cursor/skills/dev-flow/SKILL.md"
test -f "$tmp/.cursor/commands/dev-flow-start.md"
test ! -e "$tmp/.claude/settings.json"
```

- [ ] **Step 2: Verify red then implement**

Run: `bash tests/codex_cursor_adapter_test.sh`

Expected: FAIL before adapters are complete.

Install Codex skill and Cursor skill/commands from canonical sources; emit `continuation_gate=unavailable` unless a verified local probe enables it.

- [ ] **Step 3: Verify and commit**

Run: `bash tests/codex_cursor_adapter_test.sh && bash tests/client_capabilities_test.sh`

Expected: both PASS.

```bash
git add install.sh tests/codex_cursor_adapter_test.sh config/client-capabilities.json
git commit -m "feat: install Codex and Cursor dev-flow adapters"
```

### Task 4: Target-aware update and release verification

**Files:** Modify `commands/dev-flow/update.md`, `tests/cli_update_test.sh`; create `tests/installer_integration_test.sh`.

- [ ] **Step 1: Add failing target update test**

```bash
output="$(cd "$tmp" && bash "$INSTALLER" cursor)"
echo "$output" | grep -q 'Selected target: cursor'
```

- [ ] **Step 2: Implement and verify**

Make generated update wrappers run `bash install.sh <target>`; test first install, reinstallation, dry run, migration conflicts, capability reports, and no cross-target writes.

Run: `bash tests/cli_update_test.sh && bash tests/installer_integration_test.sh`

Expected: both PASS.

- [ ] **Step 3: Run suite and commit**

```bash
for t in tests/*_test.sh; do bash "$t" || exit 1; done
git add commands/dev-flow/update.md tests/cli_update_test.sh tests/installer_integration_test.sh
git commit -m "feat: refresh dev-flow adapters by target"
```

Expected: every test prints `PASS:`.

## Self-Review

- Tasks cover installer isolation, migration, Claude enforcement, Codex/Cursor fallback, update, and release tests.
- No task writes outside a temporary fixture during tests.
- All target names match `config/client-capabilities.json`.
