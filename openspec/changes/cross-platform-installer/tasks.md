## 1. Define portable installation contracts

- [ ] 1.1 Inspect and document the exact project-local command, skill, and hook formats supported by the target Claude Code, Codex, and Cursor versions.
- [ ] 1.2 Define the canonical neutral state and configuration locations, legacy `.claude/` migration rules, and conflict error messages.
- [ ] 1.3 Create a machine-readable client capability matrix covering command entry points, skill entry points, continuation-gate enforcement, and target-aware update behavior.

## 2. Build the installer foundation

- [ ] 2.1 Add an executable root `install.sh` with validated `claude`, `codex`, `cursor`, and `all` target selection plus a no-write dry-run mode.
- [ ] 2.2 Add installer helpers that create required target directories, write only CodeFlow-owned files, and produce deterministic per-target summaries.
- [ ] 2.3 Implement idempotent state/config migration from the legacy Claude location to the neutral CodeFlow location, including conflict detection with no overwrite.
- [ ] 2.4 Add focused shell tests for valid/invalid target selection, dry runs, idempotency, owned-file boundaries, and state migration conflicts.

## 3. Add client adapters

- [ ] 3.1 Add canonical adapter templates/wrappers for start, stop, status, and update that delegate to shared dev-flow behavior without duplicating phase transitions.
- [ ] 3.2 Implement Claude Code installation, including the supported command/skill layout and exactly-one owned continuation-gate registration where the verified hook mechanism is available.
- [ ] 3.3 Implement Codex installation using its verified project-local command and skill layout, with explicit capability output when no continuation gate is available.
- [ ] 3.4 Implement Cursor installation using its verified project-local command and skill layout, with explicit capability output when no continuation gate is available.
- [ ] 3.5 Add fixture-based smoke tests proving each target exposes all four controls and does not depend on another target directory at runtime.

## 4. Integrate update and verify the matrix

- [ ] 4.1 Refactor the canonical update control and generated wrappers so each invokes `install.sh` for its owning target and preserves the missing-installer message.
- [ ] 4.2 Add behavioral tests for target-aware update invocation and installer-absent graceful degradation.
- [ ] 4.3 Add an all-target integration test covering first install, reinstall, capability reporting, and legacy-state migration.
- [ ] 4.4 Run the complete existing suite plus new installer/adaptor tests and document the supported-versus-degraded behavior for each client.
