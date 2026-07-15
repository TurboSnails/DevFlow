## Why

`orchestration-engine`'s `dev-flow` skill auto-starts a cycle when the user describes a development request, and its Stop hook auto-continues the cycle until it reaches `done`, `paused`, or `await-approval`. But there is currently no way for a user to explicitly kick off a cycle by name, check what phase it's in without waiting for the skill to report, or deliberately stop a cycle mid-flight — the SKILL.md's own "用户要求停止" section already assumes a `/dev-flow:stop` command exists, but nothing implements it yet. CodeFlow needs a small, explicit control surface for the one capability every other CodeFlow feature depends on being controllable.

## What Changes

- Add `commands/dev-flow/start.md` (`/dev-flow:start <feature>`): explicit alternative to relying on auto-trigger, for when a user wants to name a cycle up front or the auto-trigger doesn't fire.
- Add `commands/dev-flow/stop.md` (`/dev-flow:stop`): deletes `.claude/dev-flow-state.json` and reports which phase the cycle had reached — this is the command `orchestration-engine`'s SKILL.md already instructs the engine to invoke when the user asks to stop.
- Add `commands/dev-flow/status.md` (`/dev-flow:status`): reads the state file (if any) and reports `feature`, `phase`, and `blocks` without altering anything.
- Add `commands/dev-flow/update.md` (`/dev-flow:update`): re-runs the (future) installer's copy step to pull the latest `dev-flow` skill/hook/reference files into the current project. This command's content documents the intended re-install flow; it depends on the `installer` capability's `install.sh` to actually exist, which is out of scope for this change (see Impact).

## Capabilities

### New Capabilities
- `cli-commands`: the four `/dev-flow:*` commands that let a user explicitly start, stop, inspect, and update a dev-flow installation, all implemented as plain commands (never auto-triggered), per this project's single-auto-trigger rule.

### Modified Capabilities
(none — these commands read/write the state file schema `orchestration-engine` already defines; they don't change its requirements)

## Impact

- New files only: `commands/dev-flow/start.md`, `commands/dev-flow/stop.md`, `commands/dev-flow/status.md`, `commands/dev-flow/update.md`.
- Depends on `lib/state.sh` (from `orchestration-engine`, already shipped) for `stop`/`status`.
- `update.md`'s content references `install.sh`, which does not exist yet (the `installer` capability hasn't been built). This is the same forward-reference pattern already used for `/gs:ship` (referenced by name before `gstack-bridge` existed) — the command documents intended behavior now; it becomes runnable once `installer` ships.
