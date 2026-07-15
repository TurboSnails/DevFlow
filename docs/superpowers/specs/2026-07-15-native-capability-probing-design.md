# Native Capability Probing Design

## Purpose

Extend CodeFlow's cross-platform installer so Claude Code, Codex, and Cursor
use native commands and continuation hooks when a verified local capability is
available. If a capability cannot be detected or verified, installation still
succeeds with a prompt-guided workflow and an explicit status report.

## Architecture

`install.sh` reads `config/client-capabilities.json`, inspects the selected
project-local client integration surface, installs the canonical dev-flow skill
and any supported command wrappers, then prints per-capability results. The
canonical workflow remains under `skills/dev-flow/` and `commands/dev-flow/`;
generated client files are CodeFlow-owned adapters only.

Each detected capability has one of three statuses:

- `enabled`: the verified native integration was installed.
- `unavailable`: no local native mechanism is present; prompt-guided control is installed instead.
- `unsupported-version`: a recognizable mechanism exists but does not meet the adapter's verified contract.

## Client Behavior

- Claude Code installs the skill, four `/dev-flow:*` commands, and one
  CodeFlow-owned Stop gate entry merged into `.claude/settings.json`.
- Codex always installs the project skill. Native command and hook adapters
  are installed only after their contracts are detected; otherwise the skill
  exposes explicit controls as prompt-guided actions and reports the missing
  capability.
- Cursor installs the skill and Markdown slash commands. A native continuation
  hook is installed only when its verified contract is detected; otherwise it
  remains prompt-guided.

## State and Configuration

All adapters use `.codeflow/dev-flow-state.json` and
`.codeflow/dev-flow.config.json`. On first installation, the installer migrates
each legacy `.claude/` file only if its neutral replacement does not exist. If
both files exist, it leaves both unchanged and exits with a precise conflict
message.

## Safety Rules

- Probes read only project-local files and do not download tools or alter user-level configuration.
- `--dry-run` reports planned writes and detected capability statuses without changing files.
- The installer replaces only files marked CodeFlow-owned.
- Claude settings are structurally merged; unrelated settings and hooks are preserved.
- A target-specific update invokes `install.sh <target>` and never refreshes another client implicitly.

## Verification

Tests must cover native-capability detection, unavailable and unsupported
outcomes, target selection, dry runs, idempotent reinstallation, state
migration conflicts, settings preservation, target file layouts, target-aware
updates, and the existing dev-flow suite.

## Scope

This design does not install client applications, modify global settings, or
claim a native command/hook where no verified local contract exists.
