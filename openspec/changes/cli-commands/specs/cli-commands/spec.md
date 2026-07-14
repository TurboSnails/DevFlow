## ADDED Requirements

### Requirement: `/dev-flow:start` delegates to the dev-flow skill
`commands/dev-flow/start.md` SHALL take a feature name from its arguments and invoke the `dev-flow` skill to start a new cycle for that feature, without independently reimplementing any state-initialization or phase-sequencing logic.

#### Scenario: User explicitly starts a cycle
- **WHEN** the user runs `/dev-flow:start add-user-auth`
- **THEN** the command invokes the `dev-flow` skill, passing `add-user-auth` as the feature to start, and the skill's own cycle-start instructions (from `orchestration-engine`) take over from there

### Requirement: `/dev-flow:stop` reads progress before deleting state
`commands/dev-flow/stop.md` SHALL read the current `feature` and `phase` from `.claude/dev-flow-state.json` (via `lib/state.sh`) before deleting that file, then report the phase the cycle had reached.

#### Scenario: Stopping an in-progress cycle
- **WHEN** the user runs `/dev-flow:stop` while a state file exists with `feature="add-user-auth"` and `phase="build"`
- **THEN** the command reports that the cycle for `add-user-auth` was stopped at phase `build`, and `.claude/dev-flow-state.json` no longer exists afterward

#### Scenario: Stopping with no active cycle
- **WHEN** the user runs `/dev-flow:stop` and `.claude/dev-flow-state.json` does not exist
- **THEN** the command reports there is no active cycle to stop and takes no destructive action

### Requirement: `/dev-flow:status` reports state without modifying it
`commands/dev-flow/status.md` SHALL read and report `feature`, `phase`, and `blocks` from the state file (via `lib/state.sh`) without altering the file in any way, or report that there is no active cycle if the file doesn't exist.

#### Scenario: Checking status of an active cycle
- **WHEN** the user runs `/dev-flow:status` while a state file exists with `feature="add-user-auth"`, `phase="verify"`, `blocks="12"`
- **THEN** the command reports all three values, and the state file is unchanged afterward

#### Scenario: Checking status with no active cycle
- **WHEN** the user runs `/dev-flow:status` and `.claude/dev-flow-state.json` does not exist
- **THEN** the command reports there is no active cycle

### Requirement: `/dev-flow:update` degrades gracefully when the installer isn't present
`commands/dev-flow/update.md` SHALL check for an `install.sh` script before attempting to run it, and SHALL report plainly (without guessing or attempting an alternative action) if it is not present.

#### Scenario: Installer script is present
- **WHEN** the user runs `/dev-flow:update` and `install.sh` exists at the project root
- **THEN** the command runs it to refresh the project's dev-flow files

#### Scenario: Installer script is not yet present
- **WHEN** the user runs `/dev-flow:update` and `install.sh` does not exist
- **THEN** the command reports that the installer isn't available yet and takes no action, rather than guessing at an alternative update mechanism

### Requirement: Commands never carry skill-style auto-trigger behavior
All four command files SHALL live under `commands/dev-flow/`, not `skills/`, so they are only invoked by explicit slash-command name and never semantically auto-triggered — a `description:` frontmatter field is expected and conventional on a command file (used for `/help` listing, matching this repo's existing command files such as `.claude/commands/opsx/propose.md`) and does NOT cause auto-triggering; only a file under a `skills/` directory with a matching `SKILL.md` structure is semantically matched and auto-triggered by Claude Code.

#### Scenario: Reviewing the command files
- **WHEN** any of `commands/dev-flow/start.md`, `stop.md`, `status.md`, `update.md` is inspected
- **THEN** each lives under `commands/dev-flow/` (not under any `skills/` directory), and the `dev-flow` skill (in `skills/dev-flow/SKILL.md`) remains the only auto-triggered entry point in the project
