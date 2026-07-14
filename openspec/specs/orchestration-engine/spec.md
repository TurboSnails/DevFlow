# orchestration-engine Specification

## Purpose
TBD - created by archiving change orchestration-engine. Update Purpose after archive.
## Requirements
### Requirement: Single auto-triggered entry point
The `dev-flow` skill SHALL be the only Claude Code skill in a CodeFlow-installed project whose `description` causes auto-triggering on development requests. All other CodeFlow-provided capabilities SHALL be implemented as commands (explicit invocation only), never as auto-triggered skills.

#### Scenario: User states a development request in plain language
- **WHEN** the user describes a coding task (bug fix, feature, refactor) without invoking any slash command
- **THEN** the `dev-flow` skill is the one that activates, and no other CodeFlow-provided skill activates concurrently or instead

### Requirement: Run-level state file
The engine SHALL persist run-level state in `.claude/dev-flow-state.json` with fields `feature` (string), `phase` (string), `blocks` (integer, default 0), and `spec_tool` (string). The engine SHALL create this file when a cycle starts and SHALL update `phase` as the cycle advances.

#### Scenario: Cycle starts
- **WHEN** the `dev-flow` skill begins a new cycle for a feature
- **THEN** `.claude/dev-flow-state.json` is created with `phase` set to `propose`, `blocks` set to `0`, and `feature`/`spec_tool` populated

#### Scenario: Cycle advances
- **WHEN** the engine finishes the work for the current phase
- **THEN** it updates `phase` in the state file to the next phase in the fixed sequence before attempting to end its turn

### Requirement: Fixed phase sequence
The engine SHALL drive the cycle through exactly this sequence, in order, with no skipped or reordered phases: `propose → await-approval → plan → build → verify → ship → archive → done`.

#### Scenario: Normal completion
- **WHEN** every phase from `propose` through `archive` completes without error
- **THEN** the state file's `phase` reaches `done` and the engine stops advancing further

### Requirement: Forced continuation via Stop hook
A Stop hook (`hooks/dev-flow-gate.sh`) SHALL run on every Claude stop attempt. If `.claude/dev-flow-state.json` exists and its `phase` is not one of `done`, `paused`, or `await-approval`, the hook SHALL return a decision that blocks the stop and instructs the engine to continue to the next phase.

#### Scenario: Claude tries to stop mid-cycle
- **WHEN** the engine finishes a phase other than `await-approval` and attempts to end its turn
- **THEN** the Stop hook returns `{"decision":"block","reason": "..."}` and Claude continues instead of ending its turn

#### Scenario: No cycle in progress
- **WHEN** `.claude/dev-flow-state.json` does not exist
- **THEN** the Stop hook exits without blocking, and normal (non-dev-flow) conversations are unaffected

### Requirement: Human approval checkpoint
The engine SHALL pause for human input exactly once per cycle, at the `await-approval` phase, immediately after the `propose` phase produces a spec. The Stop hook SHALL allow the stop when `phase` is `await-approval`.

#### Scenario: Spec ready for review
- **WHEN** the `propose` phase completes
- **THEN** the engine sets `phase` to `await-approval`, presents the spec summary, and the Stop hook allows the turn to end without forcing continuation

#### Scenario: User approves
- **WHEN** the user responds with approval while `phase` is `await-approval`
- **THEN** the engine sets `phase` to `plan` and continues the cycle

### Requirement: Safety cap on forced continuations
The Stop hook SHALL track a `blocks` counter in the state file, incrementing it each time it forces a continuation. When `blocks` reaches 40, the hook SHALL allow the stop unconditionally regardless of `phase`.

#### Scenario: Runaway phase
- **WHEN** `phase` never advances across 40 consecutive stop attempts (e.g., due to a bug)
- **THEN** on the 40th forced continuation the hook allows the next stop attempt to succeed rather than blocking indefinitely

### Requirement: Project config fields read by the engine
The engine SHALL read three fields from `.claude/dev-flow.config.json` if present: `spec_tool` (string, selects the propose/archive delegation target), `gate_command` (string, shell command run at the `verify` phase), and `codex_review` (boolean, whether to invoke `/codex:review` at the `verify` phase). The engine SHALL NOT create or modify this file.

#### Scenario: Verify phase with gate command configured
- **WHEN** the engine reaches the `verify` phase and `gate_command` is a non-empty string
- **THEN** the engine runs that exact command and requires it to succeed before advancing to `ship`

#### Scenario: Verify phase with no gate command configured
- **WHEN** `gate_command` is empty or absent
- **THEN** the engine skips the automated check and proceeds to the next verify sub-step (Codex review, if enabled)

### Requirement: Delegated propose/archive behavior by naming convention
At the `propose` and `archive` phases, the engine SHALL read `spec_tool` from config and follow the instructions found in `skills/dev-flow/references/spec-tool-<spec_tool>.md`, without embedding spec-tool-specific logic in its own instructions.

#### Scenario: Configured spec tool has a reference file
- **WHEN** `spec_tool` is `"openspec"` and `skills/dev-flow/references/spec-tool-openspec.md` exists
- **THEN** the engine follows that file's propose-phase and archive-phase instructions

#### Scenario: Configured spec tool has no reference file
- **WHEN** `spec_tool` names a value with no matching `references/spec-tool-<value>.md` file
- **THEN** the engine does not guess or skip the phase; it pauses, sets `phase` to `paused`, and asks the user to fix the configuration

### Requirement: Delegated ship behavior by command-name convention
At the `ship` phase, the engine SHALL invoke the command `/gs:ship` by name, without depending on or embedding that command's implementation.

#### Scenario: Ship phase runs
- **WHEN** the engine reaches the `ship` phase
- **THEN** it invokes `/gs:ship` and advances to `archive` only after that command completes successfully

