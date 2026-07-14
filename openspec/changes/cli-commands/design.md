## Context

`orchestration-engine`'s SKILL.md already assumes three of these four commands exist: its "用户要求停止" section says the engine calls `/dev-flow:stop`, and its "启动新一轮循环" section says a cycle can start via `/dev-flow:start <feature>` in addition to auto-trigger. Nothing implements any of the four commands yet. This capability is deliberately thin: Claude Code draws a hard line between **skills** (auto-triggered by semantic match on `description`) and **commands** (only run on explicit invocation) — `orchestration-engine`'s single-auto-trigger rule depends on every other CodeFlow capability staying on the command side of that line. These four files must never gain skill-style auto-triggering.

## Goals / Non-Goals

**Goals:**
- Four command files, each doing exactly one small, well-defined operation on the run-state file or (for `start`) on triggering the engine.
- `start` does not duplicate any of the engine's own cycle-start logic (state_init, phase sequencing) — it delegates to the already-fully-specified `dev-flow` skill.
- `stop` and `status` are self-contained (source `lib/state.sh` directly) since they must work even while the engine itself isn't actively "thinking" (e.g., a user checking status between turns).
- Both `stop` and `status` handle "no cycle in progress" gracefully — reporting that plainly rather than erroring.
- `update` degrades gracefully if `installer`'s `install.sh` doesn't exist yet (this change ships before `installer` does).

**Non-Goals:**
- Not building `install.sh` itself — that's `installer`'s job. `update.md` only documents the intended call.
- Not adding any new state-file fields or hook behavior — this capability only reads/writes the schema `orchestration-engine` already owns.
- Not adding a `description:` frontmatter field that causes auto-triggering to any of these four files — if a future editor of this repo adds one, that would violate the project's single-auto-trigger rule established by `orchestration-engine`.

## Decisions

**1. `start.md` invokes the `dev-flow` skill directly via the Skill tool, rather than re-describing state_init/phase logic.**
Rationale: `orchestration-engine`'s SKILL.md already fully specifies what "启动新一轮循环" does (read config, `state_init`, enter `propose`). Re-describing that here would create two places that could drift out of sync — exactly the duplication this project's capability boundaries are designed to avoid. `start.md`'s entire job is: take the feature name from `$ARGUMENTS`, and invoke the `dev-flow` skill, framing the request as "start a new cycle for `<feature>`." This mirrors the existing pattern in this repo where `.claude/commands/opsx/propose.md` is a thin command that invokes the `opsx:propose` skill rather than reimplementing it.

**2. `stop.md` and `status.md` are self-contained — they source `lib/state.sh` directly rather than invoking the skill.**
Alternative considered: route these through the `dev-flow` skill too, for consistency with `start`. Rejected — the whole point of `stop`/`status` is that they must work reliably as quick, deterministic reads/writes regardless of what the engine is doing conversationally; routing them through the skill adds a layer of LLM interpretation to what should be a mechanical file operation (read three fields, or delete one file). This mirrors `hooks/dev-flow-gate.sh`'s own relationship to `lib/state.sh` — direct library use for anything that must be deterministic.

**3. `stop.md` reads `feature` and `phase` BEFORE deleting the state file, so it can report progress.**
Order matters: `state_get feature`, `state_get phase` → delete `.claude/dev-flow-state.json` → report "stopped at phase `<phase>` for feature `<feature>`." Reading after deletion would fail (file gone). If no state file exists, `stop.md` reports there is no active cycle to stop and takes no action (not an error — same "already at rest" tolerance `hooks/dev-flow-gate.sh` already has for a missing state file).

**4. `status.md` reports all three of `feature`, `phase`, `blocks`, plainly, or "no active cycle" if the state file doesn't exist.**
No interpretation or summarization — this command is a raw diagnostic tool. Rationale: a user debugging why a cycle seems stuck wants the actual `blocks` counter value (to judge proximity to the 40-cap) as much as the phase name.

**5. `update.md` checks for `install.sh` at the repo root before doing anything, and reports plainly if it's absent — it does not attempt any alternative action.**
This is the same "never guess, tell the user plainly" pattern `orchestration-engine`'s SKILL.md already uses for a missing `spec-tool-<value>.md` reference file. Since `installer` doesn't exist yet as of this change, `update.md` shipping now is intentionally inert until `installer` lands — at that point no change to `update.md` is needed, it starts working the moment `install.sh` exists.

**6. None of the four command files carry a `description:` frontmatter field of the kind that causes skill auto-triggering.**
Commands in Claude Code are invoked purely by their explicit slash name (`/dev-flow:start`, etc.) — they have no semantic auto-trigger mechanism the way skills do, so there is no field to avoid adding in the way `orchestration-engine`'s single-auto-trigger rule would otherwise require policing. This decision exists to make that distinction explicit for whoever reviews this change: commands are categorically exempt from the auto-trigger rule, not merely well-behaved under it.

## Risks / Trade-offs

- [Risk] `update.md` is untestable end-to-end until `installer` ships (there's nothing to actually run). → Mitigation: its structural test only verifies the file documents the check-and-degrade behavior correctly, not that a real `install.sh` run succeeds; this is consistent with how `spec-tool-adapter`'s reference files were tested before `gstack-bridge` existed to back `/gs:ship`.
- [Risk] `start.md` delegating to the skill via the Skill tool means its behavior is only as good as the skill's own instructions — if `orchestration-engine`'s SKILL.md ever changes its cycle-start behavior, `start.md` doesn't need to change, but also can't independently guarantee correctness. → Mitigation: this is the intended trade-off (decision 1) — a single source of truth for cycle-start logic is worth the coupling.
- [Trade-off] `stop`/`status` bypass the skill entirely, meaning they don't go through any LLM judgment about *whether* stopping/checking makes sense right now — they always act mechanically. Accepted: this is exactly what makes them reliable diagnostic/control tools rather than more engine behavior.

## Migration Plan

Purely additive — four new files, no existing behavior changes. Rollback is deleting the four files; nothing else depends on their existence except that `orchestration-engine`'s SKILL.md *prose* refers to `/dev-flow:stop` by name (that reference doesn't break anything mechanically if the command is absent — it would just mean the engine's instruction to invoke it fails at runtime, same class of gap the whole project already tolerates for forward-referenced commands like `/gs:ship`).

## Open Questions

None outstanding — this capability is small and self-contained.
