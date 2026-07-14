## Why

The `orchestration-engine` capability (already implemented) defines a delegation contract: at the `propose` and `archive` phases, the `dev-flow` skill reads `spec_tool` from `.claude/dev-flow.config.json` and follows instructions in `skills/dev-flow/references/spec-tool-<spec_tool>.md`, pausing if that file doesn't exist. No such reference files exist yet, so today every cycle would stall at the first `propose` phase. CodeFlow needs to support both brownfield projects (OpenSpec) and greenfield projects (Spec Kit) without the engine ever embedding tool-specific logic, per the project's own decision to keep those two tools interchangeable via a naming convention rather than a branching `if` inside the engine.

## What Changes

- Add `skills/dev-flow/references/spec-tool-openspec.md`: propose-phase instructions that drive `/opsx:propose <feature>` (or equivalent OpenSpec command chain) to produce a spec, and archive-phase instructions that drive `/opsx:archive`.
- Add `skills/dev-flow/references/spec-tool-speckit.md`: propose-phase instructions that drive the Spec Kit chain (`/speckit.specify` → `/speckit.clarify` → `/speckit.plan` → `/speckit.tasks`), and archive-phase instructions noting Spec Kit has no archive command (the design's earlier open note: this branch ends the cycle at `done` directly with no archival step).
- Each reference file follows one required internal structure so the engine's delegation (which only knows the file-naming convention, not file contents) works identically regardless of which tool is configured: a `## propose 阶段做什么` section and an `## archive 阶段做什么` section, matching the exact section names `orchestration-engine`'s SKILL.md already references (`skills/dev-flow/SKILL.md:58,94`).

## Capabilities

### New Capabilities
- `spec-tool-adapter`: the two reference files (`spec-tool-openspec.md`, `spec-tool-speckit.md`) that let `orchestration-engine`'s propose/archive phases delegate to either spec tool by naming convention alone.

### Modified Capabilities
(none — `orchestration-engine`'s own spec is unchanged; this change only adds the reference files it already expects to find)

## Impact

- New files only: `skills/dev-flow/references/spec-tool-openspec.md`, `skills/dev-flow/references/spec-tool-speckit.md`.
- No changes to `lib/state.sh`, `hooks/dev-flow-gate.sh`, or `skills/dev-flow/SKILL.md` (orchestration-engine's delegation contract is consumed as-is, not modified).
- Unblocks real end-to-end use of the `dev-flow` skill: without this change, every cycle pauses at `propose` because no reference file exists for any `spec_tool` value.
