## Context

CodeFlow packages a multi-stage dev workflow (spec → plan → build → verify → ship → archive) as an installable `.claude/` skill set. Two other capabilities will exist in this same repo and depend on this one: `spec-tool-adapter` (chooses OpenSpec vs Spec Kit command chains) and `gstack-bridge` (provides `/gs:ship` and other borrowed commands). Those capabilities are proposed separately; this design must define stable contracts they can build against without this engine needing to know their internals.

Claude Code has two trigger mechanisms: skills (auto-triggered by semantic match on `description`) and commands (only run when explicitly invoked). Prior art (Superpowers + Gstack installed together) shows that multiple auto-triggered skills with overlapping descriptions cause Claude to pick the wrong one or blend instructions. This design's most important constraint is: **exactly one skill in this whole system may be auto-triggered.**

## Goals / Non-Goals

**Goals:**
- One auto-triggered skill (`dev-flow`) drives the entire cycle; every other CodeFlow capability is a plain command (no `description`-based auto-trigger).
- Once started, the cycle continues stage-to-stage without the user re-invoking a command, until it reaches `done` or the user explicitly stops it.
- Exactly one stage (`await-approval`) pauses for a human decision; every other pause is treated as "Claude tried to stop early" and is blocked.
- The engine has zero knowledge of *which* spec tool or *which* ship mechanism is in use — those are pluggable via file-naming and command-naming conventions.
- A runaway loop is impossible even if the state file is left in a bad state (hard cap on forced continuations).

**Non-Goals:**
- This capability does not implement `/gs:ship`, the OpenSpec/Spec Kit command chains, the `/dev-flow:*` commands, or the installer. Those belong to `gstack-bridge`, `spec-tool-adapter`, `cli-commands`, and `installer` respectively.
- This capability does not define how `.claude/dev-flow.config.json` gets created on disk (installer's job) — only the schema of the three fields it reads from that file.
- Not building a general-purpose workflow engine for arbitrary phase graphs — the phase sequence is fixed and linear by design (see Decisions).

## Decisions

**1. Fixed linear phase sequence, not a configurable graph.**
`propose → await-approval → plan → build → verify → ship → archive → done`.
Alternative considered: make phases/order configurable per project. Rejected — the whole point of CodeFlow is a shared, predictable cycle across projects; a configurable graph adds complexity for a flexibility need that hasn't appeared yet (YAGNI). If a real need for branching phases emerges later, it can be a new design.

**2. State lives in a runtime JSON file, not skill memory or conversation state.**
`.claude/dev-flow-state.json`: `{"feature": string, "phase": string, "blocks": number, "spec_tool": string}`.
Rationale: the Stop hook is a separate shell process with no access to conversation context — it can only make its block/allow decision from something durable on disk. This mirrors the pattern already used by `dev-flow.config.json` (project-level config) vs this file (run-level state); config is written once by the installer, state is written/updated by the skill and cleared by `/dev-flow:stop` (owned by `cli-commands`).

**3. Continuation is enforced by a Stop hook returning `decision: block`, not by prompt instructions alone.**
Alternative considered: rely on SKILL.md instructions telling Claude "don't stop." Rejected — Claude has a strong tendency to summarize and stop after each stage regardless of instructions; a prompt-only approach is unreliable exactly where reliability matters most. The hook is a deterministic code-level gate: it inspects `phase` and either allows the stop (`done`/`paused`/`await-approval`) or blocks it with a `reason` telling Claude what to do next.

**4. Blocked continuations are capped at 40, tracked in the state file itself (`blocks` field).**
Rationale: guards against infinite loops if `phase` gets stuck (e.g., a bug causes the skill to never advance `phase`). At 40, the hook allows the stop unconditionally so the session doesn't hang forever; this is a safety valve, not an expected path.

**5. `await-approval` is the only phase where blocking is suspended, by design, not by counting.**
The proposal stage produces a spec that is cheap to get wrong and expensive to build on top of if wrong — it is the one point where a human should look before the rest of the cycle (plan/build/verify/ship/archive) proceeds unattended. All other stages are gated by automated checks (tests, `gate_command`, optionally `/codex:review`) so they don't need a human in the loop.

**6. Delegation to other capabilities is via naming convention, not direct coupling.**
- Propose/archive stage behavior: engine reads `spec_tool` from config, then follows instructions in `skills/dev-flow/references/spec-tool-<value>.md`. The engine's SKILL.md does not contain OpenSpec- or Spec-Kit-specific instructions itself.
- Ship stage: engine invokes the command `/gs:ship` by name only.
Rationale: this is the seam that lets `spec-tool-adapter` and `gstack-bridge` be designed, built, and evolved independently (e.g., adding a third spec tool is "add one new reference file," not "edit the engine").

**7. Config schema (`spec_tool`, `gate_command`, `codex_review`) is defined here, authored by installer.**
This capability is the primary reader of all three fields (propose/archive dispatch, verify-stage test command, optional Codex review call), so it owns the schema definition; `installer` (separate capability) is responsible for generating the file with defaults on a project that doesn't have one yet.

## Risks / Trade-offs

- [Risk] A bug in the skill logic could leave `phase` stuck, causing 40 forced-continue cycles before the safety valve releases it → Mitigation: the block cap plus `/dev-flow:status` (owned by `cli-commands`) lets a user inspect and `/dev-flow:stop` out at any time; 40 is small enough to not burn excessive tool calls before releasing.
- [Risk] `gate_command` or `/codex:review` failing repeatedly at the `verify` stage could also drive many forced continuations → Mitigation: same block cap applies uniformly; no stage is exempt from the 40-cap ceiling.
- [Risk] If `references/spec-tool-<value>.md` is missing for a configured `spec_tool` value (e.g., typo in config), the engine has no fallback → Mitigation: SKILL.md instructs the engine to treat a missing reference file as reason to pause and ask the user, not to guess; this is a deliberate exception to "never stop early" because it's a configuration error, not stage completion.
- [Trade-off] Fixed linear sequence means no per-project custom stages. Accepted per Goals — flexibility isn't a validated requirement yet.

## Migration Plan

Greenfield capability in a new repo; no migration needed. Rollback is simply not installing this capability (or `/dev-flow:stop` + removing the state file) — no persisted state outside the project's own `.claude/` directory.

## Open Questions

- Should the `blocks` cap (40) be configurable via `dev-flow.config.json`, or stay a hardcoded constant? Leaning toward hardcoded for now (simplicity); revisit if real usage shows 40 is wrong in either direction.
