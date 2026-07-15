## Context

The repository has a portable-looking source layer (`skills/dev-flow/`, `commands/dev-flow/`, `lib/state.sh`, and `hooks/dev-flow-gate.sh`) but no installation boundary. Existing OpenSpec integrations demonstrate that Claude Code, Codex, and Cursor use different project-local locations and command naming conventions. The dev-flow source also contains Claude-specific concepts: a Skill-tool delegation, a Stop hook, and `/gs:ship`/`/codex:review` command references.

The installer must make a truthful promise: the shared workflow is available on every selected client, while native enforcement is only enabled where that client has the required integration mechanism.

## Goals / Non-Goals

**Goals:**
- One idempotent local installer for `claude`, `codex`, `cursor`, and `all`.
- One canonical dev-flow source, with client-specific entry-point wrappers generated during installation.
- A stable state-file location and deterministic command behavior across clients.
- Explicit capability reporting and smoke-testable failure messages.

**Non-Goals:**
- Installing, upgrading, or configuring the Claude Code, Codex, or Cursor applications.
- Claiming a forced-continuation hook on a client without a verified equivalent.
- Translating or implementing external `/gs:ship` and review commands.
- Supporting global/user-level installation; this change is project-local only.

## Decisions

### 1. Canonical source plus thin target adapters

Keep workflow semantics in root `skills/` and `commands/`. The installer copies shared references and creates narrowly scoped wrappers under `.claude/`, `.codex/`, and `.cursor/`.

Alternative: maintain a complete independent copy per client. Rejected because the start/stop/status/update contracts would drift and every workflow change would require triple editing.

### 2. Installer selects explicit targets and is idempotent

`install.sh` accepts one target (`claude`, `codex`, `cursor`, or `all`) and defaults to `all`. It validates the target before any write, creates required directories, replaces only files owned by CodeFlow, and prints a target-by-target summary. Re-running it produces the same installed files without duplicating configuration.

Alternative: infer the active client from the filesystem. Rejected because several clients can coexist in one project and inference would make `/dev-flow:update` ambiguous.

### 3. State remains project-local and client-neutral

`lib/state.sh` remains the sole state access API. Its default moves from the Claude-branded `.claude/dev-flow-state.json` location to a neutral CodeFlow-owned location, with a migration path for an existing Claude state file. All generated wrappers source the same library.

Alternative: keep a separate state file per client. Rejected because a project used in multiple clients would report conflicting cycle state.

### 4. Capability matrix is explicit

Every installation writes or reports the selected target's capabilities. Claude Code receives a continuation-gate registration only when the installed version's hook configuration is supported. Codex and Cursor adapters provide explicit commands and workflow guidance, but report `continuation_gate=unavailable` unless a verified native adapter is supplied. No adapter silently substitutes a different enforcement behavior.

Alternative: emulate forced continuation in prompt text for all clients. Rejected because prompt text is not an equivalent enforcement mechanism.

### 5. Update is target-aware

Generated `/dev-flow:update` wrappers invoke `install.sh <target>`. The canonical command text is refactored so it does not tell every client to run an ambiguous bare installer.

Alternative: have update refresh all clients. Rejected because a user invoking it from one client should not unexpectedly change other checked-in integration directories.

## Risks / Trade-offs

- [Risk] Client integration formats or hook support may differ by installed product version. → Mitigation: adapters validate prerequisites, expose capability status, and fail plainly rather than guessing.
- [Risk] Moving the state path could abandon a running Claude cycle. → Mitigation: migrate the legacy state file atomically on first installation and refuse to overwrite conflicting active state.
- [Risk] Generated files could overwrite user customization. → Mitigation: limit writes to an identified CodeFlow-owned file set and provide a `--dry-run` mode.
- [Risk] Three adapters introduce test surface. → Mitigation: fixture-based install tests assert file layouts, idempotency, command behavior, and declared capability matrices.

## Migration Plan

1. Add the installer, canonical templates, and tests without deleting existing integrations.
2. Install each target into a temporary project fixture and run its smoke test.
3. On first installation, migrate an existing `.claude/dev-flow-state.json` only if the neutral state file is absent.
4. Roll back by removing only installer-owned adapter files; retain the neutral state file unless the user explicitly removes it.

## Open Questions

- Which verified Codex and Cursor integration mechanisms, if any, can register an equivalent continuation gate in the target versions to support?
- Should legacy `.claude/dev-flow.config.json` move with state into the neutral location, or remain as a backward-compatible configuration source?
