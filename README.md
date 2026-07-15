# CodeFlow

CodeFlow packages a self-driving development workflow — spec → plan → build →
verify → ship → archive — as an installable skill/command bundle for Claude
Code, Codex, and Cursor. Describe what you want to build; the `dev-flow`
skill takes it from a proposal through to a shippable PR without you having
to re-invoke a command after every stage. It pauses for you exactly once
(to approve the spec) and otherwise keeps going until it's done or you tell
it to stop.

## Why

Two problems this solves:

1. **Skill collisions.** Installing several agent-skill packages side by
   side (e.g. a TDD/planning toolkit alongside a product/ops toolkit) means
   multiple auto-triggered skills competing to interpret the same request.
   CodeFlow keeps exactly one skill (`dev-flow`) auto-triggered per project;
   everything else — including its own control surface and its Gstack-style
   ship/freeze/retro commands — is a plain, explicitly-invoked command.
2. **Manual re-invocation fatigue.** Running spec → plan → build → verify →
   ship as five separate manual steps means babysitting the session between
   every stage. A Stop hook forces the cycle to keep going until it reaches
   a real stopping point (`done`, `paused`, or the one deliberate
   `await-approval` pause), so you don't have to.

## Install

```bash
git clone git@github.com:TurboSnails/DevFlow.git ~/.codeflow-src
cd /path/to/your-project
~/.codeflow-src/install.sh claude   # or: codex | cursor | all (default: all)
```

Re-run the same command any time to pick up updates (`/dev-flow:update` does
this for you from inside a project — see below). `--dry-run` shows what
would be installed/migrated without writing anything:

```bash
~/.codeflow-src/install.sh --dry-run all
```

### What gets installed, per client

| Client | Skill | Control commands | `/gs:*` commands | Continuation gate |
|---|---|---|---|---|
| **Claude Code** | `.claude/skills/dev-flow/` | `.claude/commands/dev-flow/{start,stop,status,update}.md` | `.claude/commands/gs/{ship,freeze,office-hours,retro,cso}.md` | Native — enforced by a real Stop hook + PreToolUse hook, registered in `.claude/settings.json` |
| **Codex** | `.codex/skills/dev-flow/` | — (no command surface yet) | — | Unavailable — prompt-guided only, no hook mechanism |
| **Cursor** | `.cursor/skills/dev-flow/` | `.cursor/commands/dev-flow-{start,stop,status,update}.md` | `.cursor/commands/gs-{ship,freeze,office-hours,retro,cso}.md` | Unavailable — prompt-guided only |

Only Claude Code gets real enforcement (the Stop hook that forces the cycle
to continue, and the PreToolUse hook that blocks edits to frozen paths).
On Codex/Cursor the same skill and command text is installed, but nothing
mechanically stops the agent from ending its turn early or editing a frozen
file — the workflow relies on the assistant following its own instructions.
See `config/client-capabilities.json` for the machine-readable version of
this table.

Project state and config live under `.codeflow/` (not any client's own
directory), so they're shared across whichever clients you've installed:
`.codeflow/dev-flow-state.json` (run-time) and
`.codeflow/dev-flow.config.json` (project settings, see below). If you have
files at the older `.claude/dev-flow-state.json` / `.claude/dev-flow.config.json`
locations from before this convention existed, the installer migrates them
automatically the first time you run it.

## The dev-flow cycle

```
propose → await-approval → plan → build → verify → ship → archive → done
```

- **propose** — generates a spec (via OpenSpec or Spec Kit, see
  "Spec tool" below), then pauses.
- **await-approval** — the *only* deliberate pause. Review the spec, reply
  to approve, and the cycle continues.
- **plan** — turns the approved spec into a step-by-step implementation
  plan (delegates to Superpowers' `writing-plans` skill).
- **build** — implements the plan task-by-task under TDD.
- **verify** — runs your configured `gate_command` (tests/lint) and,
  optionally, `/codex:review`; both must pass.
- **ship** — runs `/gs:ship`: commit, push, open a PR, wait for CI, and
  report the result. It never merges — merging is always a separate,
  manual action you take later.
- **archive** — files the spec away (via OpenSpec/Spec Kit), then the
  cycle reaches `done`.

A Stop hook (`hooks/dev-flow-gate.sh`) forces the assistant to keep
advancing through this sequence any time it tries to end its turn outside
of `await-approval`, `paused`, or `done` — up to a safety cap of 40 forced
continuations *per phase* (the counter resets whenever the phase changes,
so a long but healthy `build` phase doesn't get cut off).

## Commands

### `/dev-flow:*` — control the cycle

| Command | Does |
|---|---|
| `/dev-flow:start <feature>` | Explicitly start a cycle (same effect as describing the feature in plain language — the skill auto-triggers either way) |
| `/dev-flow:stop` | Stop the current cycle and report which phase it had reached |
| `/dev-flow:status` | Report `feature` / `phase` / `blocks` without changing anything |
| `/dev-flow:update` | Re-run the installer for your client, refreshing dev-flow files in place |

### `/gs:*` and `/office-hours` — the rest of the toolkit

| Command | Does |
|---|---|
| `/gs:office-hours` | Six mandatory questions to answer before writing a spec for a non-trivial feature — a product-thinking gate, not code |
| `/gs:ship` | Commit → push → PR → wait for CI → report. Never merges. This is what the `ship` phase calls by name. |
| `/gs:freeze <path>` | Declare a path off-limits for AI-driven edits by appending it to `.claude/frozen-paths.txt` (plain text, one prefix per line — edit the file directly to un-freeze) |
| `/gs:retro` | Structured weekly retro conversation (what got done / what's stuck / what's next) |
| `/gs:cso` | Security-audit checklist for the current branch's changes (secrets, permission changes, new dependencies, frozen-path violations) |

On Claude Code, `/gs:freeze` is actually enforced: `hooks/freeze-gate.sh`
intercepts Edit/Write/MultiEdit calls and blocks any target path under a
frozen prefix. It does **not** intercept the Bash tool — a frozen file can
still be edited via a shell command, so treat freezing as a strong hint to
the assistant, not a hard security boundary.

## Configuration

`.codeflow/dev-flow.config.json` (create it yourself; nothing generates a
default automatically):

```json
{
  "spec_tool": "openspec",
  "gate_command": "npm test",
  "codex_review": false
}
```

| Field | Values | Meaning |
|---|---|---|
| `spec_tool` | `"openspec"` \| `"speckit"` | Which spec tool drives the `propose`/`archive` phases. `openspec`: brownfield projects, delta-based proposals via `/opsx:propose` / `/opsx:archive`. `speckit`: greenfield projects, `/speckit.specify` → `.clarify` → `.plan` → `.tasks` (no archive step — Spec Kit has no archive concept). |
| `gate_command` | any shell command, or omit | Run at the `verify` phase; must exit 0 to proceed. Leave unset to skip. |
| `codex_review` | `true` \| `false` | Whether `verify` also runs `/codex:review --base main` (requires the Codex CLI plugin). |

## Repo layout (for contributors)

```
skills/dev-flow/SKILL.md              the one auto-triggered skill
skills/dev-flow/references/           spec_tool delegation targets (openspec/speckit)
lib/state.sh                          run-state + config-path helpers (state_init, state_get, ...)
hooks/dev-flow-gate.sh                Stop hook — forces cycle continuation
hooks/freeze-gate.sh                  PreToolUse hook — blocks edits to frozen paths
commands/dev-flow/*.md                /dev-flow:start|stop|status|update
commands/gs/*.md                      /gs:ship|freeze|office-hours|retro|cso
config/client-capabilities.json       machine-readable per-client capability matrix
install.sh                            installs/migrates the above into a target project
tests/*.sh                            one test file per component; run any of them directly
```

Every capability here went through spec → design → plan → TDD implementation
→ code review before merging; see `openspec/specs/` for the current
requirements and `openspec/changes/archive/` for the history.

### Running the tests

```bash
for t in tests/*.sh; do bash "$t" || exit 1; done
```

Each file is self-contained (creates its own temp state/config files, cleans
up after itself) and can also be run individually.
