# Platform Integration Contracts

This document is the verified input for the cross-platform installer.  It
deliberately separates an integration that the installer may create from a
capability that has not been verified.  An unverified path is never a
fallback.

## Shared conventions

- The canonical workflow source remains in `skills/dev-flow/` and
  `commands/dev-flow/`; client directories contain generated, CodeFlow-owned
  adapters only.
- A generated command is one Markdown file for each of `start`, `stop`,
  `status`, and `update`.  Its content delegates to the canonical source and
  does not redefine phase transitions.
- A generated skill is a directory containing `SKILL.md` with YAML front
  matter.  The validated minimal fields are `name` and `description`.
- Only Claude Code receives a continuation gate.  The Codex and Cursor
  adapters must say `continuation_gate=unavailable` and describe themselves as
  prompt-guided.

## Neutral dev-flow state and configuration

The project-local, client-neutral dev-flow data directory is `.codeflow/`.
The canonical files are:

| Purpose | Canonical path | Temporary test override |
| --- | --- | --- |
| Active cycle state | `.codeflow/dev-flow-state.json` | `DEV_FLOW_STATE_FILE` |
| Workflow configuration | `.codeflow/dev-flow.config.json` | `DEV_FLOW_CONFIG_FILE` |

`lib/state.sh` is the sole state access API.  A caller that sets
`DEV_FLOW_STATE_FILE` deliberately selects a different state file; installers
must not migrate or modify that override.  The configuration override follows
the same rule.  All installed adapters use the canonical paths by default, so
the same cycle can be observed from Claude Code, Codex, and Cursor.

### Legacy Claude migration

The installer treats `.claude/dev-flow-state.json` and
`.claude/dev-flow.config.json` as legacy files.  It evaluates state and
configuration independently before installing any target integration:

1. If only the legacy file exists, create `.codeflow/` and atomically move the
   legacy file to its matching canonical path.
2. If only the canonical file exists, retain it unchanged.
3. If neither file exists, do nothing.
4. If both matching paths exist, leave both files unchanged, stop the
   installation before writing target integrations, and require manual
   resolution.  The installer never merges JSON or chooses a winner.

The exact conflict diagnostics are deliberately stable for tests and for a
user who needs to resolve a migration:

```text
dev-flow migration conflict: both .claude/dev-flow-state.json and .codeflow/dev-flow-state.json exist; resolve the state files manually, then rerun install.sh.
dev-flow migration conflict: both .claude/dev-flow.config.json and .codeflow/dev-flow.config.json exist; resolve the configuration files manually, then rerun install.sh.
```

When both state and configuration conflict, report both lines and exit
unsuccessfully.  A dry run performs the same detection and reports planned
moves, but makes no directory or file changes.

## Claude Code

| Concern | Verified project-local contract | Installer action |
| --- | --- | --- |
| Commands | `.claude/commands/dev-flow/<control>.md`; Markdown command files use YAML front matter.  The repository's original OpenSpec commands use `name`, `description`, `category`, and `tags`. | Install four CodeFlow-owned command files. |
| Skill | `.claude/skills/dev-flow/SKILL.md`; YAML front matter followed by Markdown instructions. | Install the canonical skill content as the CodeFlow-owned skill. |
| Stop hook | `.claude/settings.json` has `hooks.Stop`, an array of hook matchers.  A matcher object has `matcher` and `hooks`; the nested command hook has `type: "command"` and `command`. | Add exactly one identifiable CodeFlow command-hook entry and preserve unrelated settings and hooks. |

The supported Stop registration shape is:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash hooks/dev-flow-gate.sh"
          }
        ]
      }
    ]
  }
}
```

The installer will use a project-root-relative CodeFlow-owned gate path rather
than relying on an ambient current working directory.  It must merge this
entry, not replace `settings.json`, and must detect an existing equivalent
entry before adding one.

## Codex

| Concern | Verified project-local contract | Installer action |
| --- | --- | --- |
| Commands | No project-local custom slash-command layout is verified for the target Codex surface. | Do not create a speculative `.codex/commands` directory.  Expose the four controls as documented sections of the installed dev-flow skill. |
| Skill | `.codex/skills/dev-flow/SKILL.md`; YAML front matter followed by Markdown instructions.  This is the existing repository integration shape and the Codex app loaded its OpenSpec skills from this location. | Install the CodeFlow-owned skill, including explicit start/stop/status/update instructions. |
| Continuation gate | No native project-local Stop-hook registration is verified. | Do not install a hook; report `continuation_gate=unavailable`. |

## Cursor

| Concern | Verified project-local contract | Installer action |
| --- | --- | --- |
| Commands | `.cursor/commands/dev-flow-<control>.md`; plain Markdown command files are discovered as slash commands.  Existing repository commands use YAML front matter, which remains allowed as Markdown content. | Install four CodeFlow-owned command files. |
| Skill | `.cursor/skills/dev-flow/SKILL.md`; YAML front matter followed by Markdown instructions.  This is the existing repository integration shape used for the OpenSpec skills. | Install the CodeFlow-owned skill as workflow guidance. |
| Continuation gate | No native project-local Stop-hook registration is verified. | Do not install a hook; report `continuation_gate=unavailable`. |

## Verification record

- Repository baseline commit `e54f23a` contains Claude Code command and skill
  files, Codex skill files, and Cursor command and skill files in exactly the
  locations listed above.
- Cursor's documented custom-command directory is `.cursor/commands`, with
  one Markdown file per command.
- Claude Code documents `settings.json` hook configuration with event arrays
  and command hooks; the Stop event is the supported enforcement point for the
  existing `hooks/dev-flow-gate.sh` contract.
- No authoritative project-local Codex command or continuation-hook format was
  available during this verification.  The installer must retain the explicit
  degraded behavior above until one is verified and this contract is updated.
