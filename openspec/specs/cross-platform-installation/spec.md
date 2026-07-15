# cross-platform-installation Specification

## Purpose
Provide a safe project-local installer for dev-flow integrations across Claude Code, Codex, and Cursor.

## Requirements

### Requirement: Installer installs a selected project-local target
The system SHALL provide a project-root installer that accepts `claude`, `codex`, `cursor`, or `all` as an installation target, defaults to `all`, and installs only the selected target integrations.

#### Scenario: Install one target
- **WHEN** a user runs the installer with `codex`
- **THEN** it installs the Codex dev-flow integration, does not modify Claude Code or Cursor integration files, and reports the installed target

#### Scenario: Reject an unknown target
- **WHEN** a user runs the installer with an unsupported target
- **THEN** it exits unsuccessfully before modifying integration files and prints the supported target names

### Requirement: Installation is idempotent and preserves non-owned files
The installer SHALL be safe to run repeatedly and SHALL replace only files that it identifies as CodeFlow-owned.

#### Scenario: Reinstalling a target
- **WHEN** a user runs the installer twice for the same target
- **THEN** the second run succeeds without duplicating generated configuration or changing non-CodeFlow files

### Requirement: Installer supports a dry run
The installer SHALL provide a dry-run mode that lists planned target-specific writes without changing the project.

#### Scenario: Preview an all-target installation
- **WHEN** a user runs the installer for `all` with dry-run enabled
- **THEN** it reports the planned writes for Claude Code, Codex, and Cursor and creates no files

### Requirement: Installer reports target capabilities truthfully
The installer SHALL report whether each selected target has an installed continuation gate, and SHALL report `unavailable` rather than claiming forced continuation where no verified native adapter exists.

#### Scenario: Target lacks a native continuation gate
- **WHEN** an adapter has no verified continuation-hook implementation for a selected target
- **THEN** the installer completes the portable command and skill installation and reports that continuation-gate enforcement is unavailable for that target

### Requirement: State migration preserves an active legacy cycle
The installer SHALL migrate an existing legacy Claude dev-flow state only when no neutral state exists and SHALL not overwrite a conflicting active state.

#### Scenario: Migrate legacy state
- **WHEN** a legacy Claude state file exists and the neutral CodeFlow state file does not exist
- **THEN** installation migrates the legacy state so later adapters observe the same feature, phase, and block count

#### Scenario: Detect conflicting states
- **WHEN** both a legacy Claude state file and a neutral CodeFlow state file exist
- **THEN** installation leaves both files unchanged and reports a conflict requiring user action
