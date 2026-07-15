# cli-commands Specification

## Purpose
Define the explicit controls used to start, inspect, stop, and refresh a dev-flow cycle.

## Requirements

### Requirement: `/dev-flow:start` delegates to the dev-flow skill
`commands/dev-flow/start.md` SHALL take a feature name from its arguments and invoke the `dev-flow` skill to start a new cycle for that feature, without independently reimplementing any state-initialization or phase-sequencing logic.

#### Scenario: User explicitly starts a cycle
- **WHEN** a user runs `/dev-flow:start add-user-auth`
- **THEN** the command invokes the `dev-flow` skill with `add-user-auth` as the feature and the skill's cycle-start instructions take over

### Requirement: `/dev-flow:stop` reads progress before deleting state
`commands/dev-flow/stop.md` SHALL use `lib/state.sh` to read the current `feature` and `phase` before deleting the active state, then report the phase the cycle had reached.

#### Scenario: Stopping an in-progress cycle
- **WHEN** a user runs `/dev-flow:stop` while an active state has `feature="add-user-auth"` and `phase="build"`
- **THEN** the command reports that the cycle for `add-user-auth` was stopped at phase `build` and removes the active state afterward

#### Scenario: Stopping with no active cycle
- **WHEN** a user runs `/dev-flow:stop` without an active state
- **THEN** the command reports there is no active cycle to stop and takes no destructive action

### Requirement: `/dev-flow:status` reports state without modifying it
`commands/dev-flow/status.md` SHALL use `lib/state.sh` to read and report `feature`, `phase`, and `blocks` without altering state, or report that there is no active cycle when no state exists.

#### Scenario: Checking status of an active cycle
- **WHEN** a user runs `/dev-flow:status` while active state has `feature="add-user-auth"`, `phase="verify"`, and `blocks="12"`
- **THEN** the command reports all three values and the state is unchanged afterward

#### Scenario: Checking status with no active cycle
- **WHEN** a user runs `/dev-flow:status` without an active state
- **THEN** the command reports there is no active cycle

### Requirement: `/dev-flow:update` refreshes the current client installation
An installed `/dev-flow:update` control SHALL invoke the project-root installer for its owning client target and SHALL report the installer's result. If the installer is absent, it SHALL report plainly that the installer is unavailable and SHALL not attempt an alternative update mechanism.

#### Scenario: Refresh an installed target
- **WHEN** a user invokes the update control installed for Cursor and the project-root installer exists
- **THEN** the control invokes the installer with the `cursor` target and reports its output

#### Scenario: Installer script is not present
- **WHEN** a user invokes an installed update control and the project-root installer does not exist
- **THEN** the control reports that the installer is unavailable and takes no action rather than guessing at an alternative update mechanism

### Requirement: Commands never carry skill-style auto-trigger behavior
All four command files SHALL live under `commands/dev-flow/`, not `skills/`, so they are only invoked by explicit command name. A `description:` frontmatter field is permitted for command discovery and SHALL NOT cause auto-triggering.

#### Scenario: Reviewing the command files
- **WHEN** any of `commands/dev-flow/start.md`, `stop.md`, `status.md`, or `update.md` is inspected
- **THEN** it lives under `commands/dev-flow/` and the `dev-flow` skill remains the only auto-triggered CodeFlow entry point
