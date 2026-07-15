## ADDED Requirements

### Requirement: Adapters expose all four dev-flow controls
Each supported client adapter SHALL expose explicit start, stop, status, and update controls that use the shared dev-flow workflow contract.

#### Scenario: Run an installed stop control
- **WHEN** a user invokes the installed stop control in any supported client
- **THEN** it uses the shared state library contract to report progress before removing the active cycle state

### Requirement: Adapters use client-appropriate entry points
Each adapter SHALL install skills and commands into that client's project-local integration directory and SHALL not require another client's directory at runtime.

#### Scenario: Cursor-only installation
- **WHEN** only the Cursor target is installed
- **THEN** the generated Cursor entry points work from `.cursor/` and no `.claude/` or `.codex/` runtime file is required

### Requirement: Adapters preserve one workflow source of truth
Client-specific wrappers SHALL delegate to canonical CodeFlow workflow content and SHALL not independently reimplement the dev-flow phase sequence or state transitions.

#### Scenario: Update phase logic in canonical source
- **WHEN** the canonical dev-flow phase sequence changes and a target is reinstalled
- **THEN** the target receives the changed workflow behavior without requiring a separate phase-sequence edit in that adapter

### Requirement: Adapters state continuation limitations plainly
An adapter without an installed verified continuation gate SHALL describe the workflow as prompt-guided and SHALL not represent it as enforced automatic continuation.

#### Scenario: Codex or Cursor without gate support
- **WHEN** a user checks the installed adapter's capability information
- **THEN** it identifies forced continuation as unavailable and describes the available explicit controls

### Requirement: Claude adapter registers the continuation gate when supported
The Claude Code adapter SHALL install and register the dev-flow continuation gate when its supported hook configuration is available.

#### Scenario: Claude hook installation
- **WHEN** the Claude target is installed in a supported project configuration
- **THEN** the installer places the gate script and adds exactly one CodeFlow-owned continuation-gate registration
