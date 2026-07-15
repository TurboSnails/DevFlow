## Why

CodeFlow's dev-flow core and control commands are tested, but they remain source files only: no installer deploys them into Claude Code, Codex, or Cursor, and the current workflow depends on Claude-specific command and Stop-hook behavior. A portable installation boundary is needed so teams can adopt the same workflow across supported clients without copying files manually or silently claiming capabilities a client does not provide.

## What Changes

- Add a cross-platform installer that installs the dev-flow source of truth into a selected client (`claude`, `codex`, `cursor`) or all supported clients.
- Add client adapters that generate each client's command and skill entry points while keeping shared workflow text and state operations centralized.
- Register the Claude Code continuation gate where supported; use explicit, documented degraded continuation behavior on clients without an equivalent gate.
- Make `/dev-flow:update` invoke the installer with the current client's target instead of remaining a placeholder.
- Add installation and smoke-test coverage for every supported target, including idempotent reinstallation and unsupported-target failures.

## Capabilities

### New Capabilities

- `cross-platform-installation`: install, refresh, and validate dev-flow integrations for Claude Code, Codex, and Cursor from one repository source of truth.
- `client-workflow-adapters`: define the per-client command, skill, and continuation-gate behavior that preserves the portable dev-flow contract without overstating native support.

### Modified Capabilities

- `cli-commands`: `/dev-flow:update` refreshes the active client installation through the new installer and reports target-specific failures plainly.

## Impact

- New root-level installer and adapter/template files; generated or copied content under `.claude/`, `.codex/`, and `.cursor/`.
- Updates to the existing `commands/dev-flow/update.md` source and associated tests.
- Claude Code hook configuration becomes an installation concern; Codex and Cursor receive documented fallback behavior when a matching continuation hook is unavailable.
- Requires Bash and the existing `jq` dependency used by `lib/state.sh`; no network service or external package installation is required.
