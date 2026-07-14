# spec-tool-adapter Specification

## Purpose
TBD - created by archiving change spec-tool-adapter. Update Purpose after archive.
## Requirements
### Requirement: Reference files match the naming convention
The capability SHALL provide `skills/dev-flow/references/spec-tool-openspec.md` and `skills/dev-flow/references/spec-tool-speckit.md`, matching the file-naming convention `references/spec-tool-<spec_tool>.md` that `orchestration-engine` already looks up by the `spec_tool` config value.

#### Scenario: Engine configured for OpenSpec
- **WHEN** `.claude/dev-flow.config.json` has `spec_tool` set to `"openspec"`
- **THEN** `skills/dev-flow/references/spec-tool-openspec.md` exists and the engine's propose/archive lookup succeeds

#### Scenario: Engine configured for Spec Kit
- **WHEN** `.claude/dev-flow.config.json` has `spec_tool` set to `"speckit"`
- **THEN** `skills/dev-flow/references/spec-tool-speckit.md` exists and the engine's propose/archive lookup succeeds

### Requirement: Required section headers match the engine's literal contract
Each reference file SHALL contain exactly two sections with the literal headers `## propose 阶段做什么` and `## archive 阶段做什么`, matching the exact section names `orchestration-engine`'s SKILL.md references when it delegates.

#### Scenario: Propose-phase lookup
- **WHEN** the engine is at the `propose` phase and has located the reference file for the configured `spec_tool`
- **THEN** the file contains a `## propose 阶段做什么` section with actionable instructions

#### Scenario: Archive-phase lookup
- **WHEN** the engine is at the `archive` phase and has located the reference file for the configured `spec_tool`
- **THEN** the file contains an `## archive 阶段做什么` section with actionable instructions

### Requirement: OpenSpec propose section drives the full proposal flow
The `spec-tool-openspec.md` propose section SHALL instruct driving `/opsx:propose <feature>` to completion (proposal, design, specs, and tasks artifacts all created) and SHALL state that the resulting spec directory is `openspec/changes/<feature>/`, where `<feature>` is the `feature` value from the run state.

#### Scenario: OpenSpec propose phase completes
- **WHEN** the engine follows `spec-tool-openspec.md`'s propose section for a feature named `add-user-auth`
- **THEN** `/opsx:propose add-user-auth` is driven to completion and the engine treats `openspec/changes/add-user-auth/` as the spec directory for the subsequent `plan` phase

### Requirement: OpenSpec archive section drives real archival
The `spec-tool-openspec.md` archive section SHALL instruct running `/opsx:archive` for the current feature's change.

#### Scenario: OpenSpec archive phase completes
- **WHEN** the engine follows `spec-tool-openspec.md`'s archive section for a feature named `add-user-auth`
- **THEN** `/opsx:archive` is run for the `add-user-auth` change before the engine advances to `done`

### Requirement: Spec Kit propose section drives the specify-through-tasks chain
The `spec-tool-speckit.md` propose section SHALL instruct driving `/speckit.specify` → `/speckit.clarify` → `/speckit.plan` → `/speckit.tasks` in that order (excluding `/speckit.constitution` and `/speckit.implement`, which are out of scope for a per-feature cycle) and SHALL state that the resulting spec directory is `specs/<feature>/`, where `<feature>` is the `feature` value from the run state.

#### Scenario: Spec Kit propose phase completes
- **WHEN** the engine follows `spec-tool-speckit.md`'s propose section for a feature named `add-user-auth`
- **THEN** the four Spec Kit commands run in order and the engine treats `specs/add-user-auth/` as the spec directory for the subsequent `plan` phase

#### Scenario: No project constitution yet
- **WHEN** the target project has never run `/speckit.constitution`
- **THEN** the propose section does not attempt to run it automatically; it is documented as a one-time manual project setup step outside the per-feature cycle

### Requirement: Spec Kit archive section is a documented no-op
The `spec-tool-speckit.md` archive section SHALL state explicitly that Spec Kit has no archive concept, that the feature's spec files under `specs/<feature>/` are the permanent record, and that no action is taken — the engine still advances to `done` after this section runs.

#### Scenario: Spec Kit archive phase completes
- **WHEN** the engine follows `spec-tool-speckit.md`'s archive section
- **THEN** no command is run, the section's content explains why, and the engine proceeds to set `phase` to `done`

