# gstack-bridge Design

## Context

`orchestration-engine`'s `dev-flow` SKILL.md already invokes `/gs:ship` by name at its `ship` phase (a forward reference, per the delegation-by-command-name convention used throughout this project — the same pattern `spec-tool-adapter` used for `/opsx:propose`/`/opsx:archive`). No `commands/gs/*` files exist yet, so a real end-to-end cycle currently stalls at `ship`. Separately, the original project brief called for a "frozen paths" mechanism (`/freeze`) that prevents AI-driven edits to sensitive directories (payment SDKs, signing configs), and a lightweight product-thinking gate (`/office-hours`) before writing a spec. None of this exists in the repo today.

This capability does not vendor content from the actual `garrytan/gstack` repository (confirmed reachable via `git ls-remote`, but per project decision, original prompt content is authored here instead — avoiding license/attribution risk and an external network dependency for something conceptually simple: git operations, a text allowlist, and conversation templates).

## Goals / Non-Goals

**Goals:**
- Five command files under `commands/gs/` (never under `skills/`, preserving `orchestration-engine`'s single-auto-trigger rule): `ship.md`, `freeze.md`, `office-hours.md`, `retro.md`, `cso.md`.
- `/gs:ship` satisfies the contract `orchestration-engine`'s SKILL.md already assumes — invoked by name, and its success unblocks the `ship → archive` transition.
- `/gs:freeze` is enforced by a **new** PreToolUse hook (`hooks/freeze-gate.sh`), the project's first hook that isn't a Stop hook — it must actually block Edit/Write attempts against frozen paths, not just document a convention.
- `/gs:retro` and `/gs:cso` are stateless conversation templates (no new files, no schema).
- `/office-hours` is a stateless six-question template used before spec-writing.

**Non-Goals:**
- Not fetching or vendoring any content from the actual `garrytan/gstack` repository — all five files are original content authored for this project.
- Not adding a `/gs:unfreeze` command — `.claude/frozen-paths.txt` is a plain, directly-editable text file (one path prefix per line), same editing model as `.gitignore`; removing a line un-freezes it.
- Not auto-merging in `/gs:ship` — merging to the base branch is the one step that stops for explicit human confirmation.
- Not building glob-pattern matching for frozen paths — simple string-prefix matching is sufficient for the stated use case (freezing whole directories or specific files).

## Decisions

**1. `/gs:ship` automates commit → push → PR → CI wait, then stops for merge confirmation.**
Rationale: push and PR creation are visible-but-reversible (a PR can be closed, force-push isn't involved); merging to the base branch is harder to reverse and affects shared state, matching this project's own risk-tiering already applied elsewhere (e.g. `await-approval` is the one deliberate pause point in `orchestration-engine`'s otherwise-automatic cycle). `/gs:ship` mirrors that shape: automate the tedious/reversible parts, pause at the one consequential step.

**2. Frozen paths live in a plain text file (`.claude/frozen-paths.txt`), one prefix per line — not JSON, not a `lib/state.sh`-style schema.**
Alternative considered: reuse the `dev-flow-state.json` pattern (a JSON file with helper functions). Rejected — frozen paths are a human-maintained allowlist meant to be hand-edited and diffed in git (same role as `.gitignore`), not runtime state a program mutates. `/gs:freeze <path>` only ever appends a line (creating the file if absent); there is no companion "read/write" library, since the only consumer (`freeze-gate.sh`) just needs to read lines and do prefix matching.

**3. `freeze-gate.sh` is a PreToolUse hook, following the same JSON-output convention as `dev-flow-gate.sh` for internal consistency, even though this is a different hook event.**
`dev-flow-gate.sh` (Stop hook) always exits 0 and communicates its decision via a JSON object on stdout (`{"decision":"block","reason":"..."}`) or empty output to allow. `freeze-gate.sh` follows the identical shape for a PreToolUse event: reads the tool invocation as JSON on stdin, extracts the target file path, checks it against `.claude/frozen-paths.txt` prefixes, and emits the same `{"decision":"block","reason":"..."}` shape (or empty output) — chosen for consistency within this repo's own hook vocabulary rather than chasing every nuance of Claude Code's official hook schema variations.

**4. Path matching is plain string-prefix matching against repo-relative paths, with an optional trailing `/**` stripped for authoring convenience.**
A line like `lib/core/payment/` or `lib/core/payment/**` both mean "everything under `lib/core/payment/`." The hook strips a trailing `/**` or `/*` before comparing, then checks whether the tool's target path starts with the (normalized, trailing-slash-ensured) prefix.

**5. `/office-hours`'s six questions are original content, not sourced from Gstack.**
Drafted to serve the stated purpose ("prevent writing a correct spec for the wrong product"): who's the user and what do they do today; what happens if we don't build this; what's the measurable definition of success; what's the smallest version 1 and what can be cut; who owns this decision and why now; if this fails, what's the most likely reason. These are a starting point the user can edit directly in the command file — no mechanism needed to make them configurable beyond that.

**6. `/gs:retro` and `/gs:cso` write nothing to disk.**
Both are conversation-shape templates (structured prompts guiding what to ask/check), matching the "stateless template" pattern already used for `/office-hours`. Per YAGNI, no retro log file or audit report file is introduced until an actual need for persisted history appears.

## Risks / Trade-offs

- [Risk] `freeze-gate.sh` is the project's first non-Stop hook, so it can't reuse `orchestration-engine`'s hook test patterns directly (those all invoke the Stop hook with no stdin). → Mitigation: its test suite constructs the PreToolUse JSON payload shape directly (`{"tool_name": "Edit", "tool_input": {"file_path": "..."}}`) as test fixtures, verified against both frozen and non-frozen paths.
- [Risk] Prefix matching could over-block (a frozen `lib/core/pay` would also block `lib/core/paylater/`) if an author doesn't add a trailing slash. → Mitigation: `/gs:freeze` always writes entries with a normalized trailing slash when given a directory-looking argument, and the hook's own comparison always compares against a slash-terminated prefix, so partial-segment false positives are prevented by construction, not just by careful authoring.
- [Trade-off] `/gs:ship` stopping before merge means it isn't a fully one-shot command despite the "one command from commit to merge" framing in the original project brief. Accepted per this project's own consistent risk-tiering (documented in decision 1) — full automation through an irreversible shared-state change was never the intent once examined against this project's existing conventions.

## Migration Plan

Purely additive: five new command files, one new hook script, one new (empty until first use) `.claude/frozen-paths.txt` convention. No existing files change. Rollback is deleting the new files and removing the hook registration.

## Open Questions

None outstanding.
