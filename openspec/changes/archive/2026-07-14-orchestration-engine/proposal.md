## Why

Superpowers (TDD/writing-plans/debugging skills) and Gstack (product/ship/operate skills) both register auto-triggered Claude Code skills with overlapping descriptions (review, plan, debug). Installing both causes Claude to match the wrong skill or blend conflicting instructions. Separately, running a full spec → plan → build → verify → ship cycle today requires the user to manually invoke each stage command in order and remember to continue after every stop. CodeFlow needs a single automation core that (a) owns the one auto-triggered entry point per project so no other skill competes for triggering, and (b) drives the multi-stage development cycle to completion without the user re-issuing a command after every stage, until the user explicitly stops it.

## What Changes

- Add a `dev-flow` Claude Code skill that is the only auto-triggered entry point for development tasks in a project using CodeFlow.
- Add a JSON state file (`.claude/dev-flow-state.json`) recording the current feature, phase, and a safety block counter.
- Define the fixed phase sequence: `propose → await-approval → plan → build → verify → ship → archive → done`, with `await-approval` as the only phase that pauses for a human decision.
- Add a Stop hook (`hooks/dev-flow-gate.sh`) that inspects the state file on every Claude "stop" attempt and returns `decision: block` to force continuation unless the phase is `done`, `paused`, or `await-approval`, or a safety cap (40 blocks) is reached.
- Define the project-level config schema (`.claude/dev-flow.config.json`) with fields `spec_tool`, `gate_command`, and `codex_review`, read by the engine but not authored by it (installer's responsibility).
- Define the delegation contract for the `propose` and `archive` phases: the engine reads `spec_tool` and defers to a file named `references/spec-tool-<value>.md` (owned by the separate `spec-tool-adapter` capability) rather than embedding tool-specific logic.
- Define the delegation contract for the `ship` phase: the engine invokes `/gs:ship` by name only, without knowing how that command is implemented (owned by the separate `gstack-bridge` capability).

## Capabilities

### New Capabilities
- `orchestration-engine`: the dev-flow skill, the state file schema, the phase sequence, and the Stop hook that enforces auto-continuation until completion or explicit stop.

### Modified Capabilities
(none — this is the first change in this project)

## Impact

- New files: `skills/dev-flow/SKILL.md`, `hooks/dev-flow-gate.sh`, `lib/state.sh` (shared state read/write helpers).
- Defines (but does not implement) the config schema consumed later by the `installer` capability and the delegation file format consumed later by `spec-tool-adapter` and `gstack-bridge`.
- No existing code affected (greenfield project).
