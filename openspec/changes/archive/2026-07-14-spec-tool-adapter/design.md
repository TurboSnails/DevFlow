## Context

`orchestration-engine` (implemented) defines the delegation contract in `skills/dev-flow/SKILL.md`: at `propose`, the engine looks up `skills/dev-flow/references/spec-tool-<spec_tool>.md` and, if found, "按该文件里 '**propose 阶段做什么**' 一节的指示生成 spec" (follows that file's "propose 阶段做什么" section); at `archive`, it does the same lookup and follows the "**archive 阶段做什么**" section (SKILL.md:58,94). If the file is missing, the engine pauses rather than guessing (SKILL.md:61-63,98-101). This design must produce two reference files — one for OpenSpec, one for Spec Kit — whose internal section names match those exact strings, since the engine's instructions were already written and reviewed against that literal contract; changing the section-name convention now would require reopening `orchestration-engine`.

The engine also passes an implicit obligation forward: the `plan` phase's instruction is "基于 propose 阶段产出的 spec 目录" (based on the spec directory the propose phase produced) — SKILL.md doesn't say what that directory is, because it's spec-tool-specific. This capability must make that directory unambiguous for whichever tool is configured.

## Goals / Non-Goals

**Goals:**
- Two reference files, each satisfying the naming convention (`spec-tool-openspec.md`, `spec-tool-speckit.md`) and each containing the two required sections with the exact literal headers the engine already expects.
- Each file's propose section leaves no ambiguity about which directory is "the spec" for the later `plan` phase to consume.
- OpenSpec's archive section drives real archival (`/opsx:archive`); Spec Kit's archive section explicitly documents that Spec Kit has no archive step and the phase is a deliberate no-op, not an oversight.
- Both files are self-contained — an engine reading either one needs no knowledge of the other tool.

**Non-Goals:**
- Not modifying `orchestration-engine`'s SKILL.md, `lib/state.sh`, or `hooks/dev-flow-gate.sh` — this capability only adds files the engine already knows how to find.
- Not building a third spec-tool adapter speculatively (YAGNI) — only OpenSpec and Spec Kit, per the proposal.
- Not handling `spec_tool` values other than `"openspec"`/`"speckit"` — an unrecognized value is already correctly handled by the engine's own missing-file pause behavior (spec-tool-adapter's job is only to exist for the two supported values, not to validate config).

## Decisions

**1. Section headers are the literal Chinese strings the engine already references, not a translated or reworded version.**
`## propose 阶段做什么` and `## archive 阶段做什么`, verbatim, in both files.
Alternative considered: use English headers (`## Propose Phase`) since that's more conventional for a technical doc. Rejected — SKILL.md was already implemented and reviewed with the exact Chinese phrase "该文件里 'propose 阶段做什么' 一节的指示"; an LLM executor reading both files in the same session should not have to reconcile two different vocabularies for the same concept. Consistency with the already-shipped contract wins over English-header convention.

**2. Each reference file states its spec directory formula explicitly, using the `feature` value from state.**
- OpenSpec: `openspec/changes/<feature>/` (matches the already-established pattern from this very project's own `orchestration-engine` and `spec-tool-adapter` changes).
- Spec Kit: `specs/<feature>/` (Spec Kit's own convention, one directory per feature, independent of OpenSpec's `changes/` vs `specs/` distinction).
Rationale: the engine's `plan` phase instruction says "基于 propose 阶段产出的 spec 目录" without specifying a path, by design (keeping the engine spec-tool-agnostic). Something has to state the path, and the natural place is the file that already knows which tool produced it — not a new field on the state file or config, which would leak spec-tool-specific concepts back into the tool-agnostic layer.

**3. OpenSpec's propose section drives the full `/opsx:propose` flow (proposal → design → specs → tasks), not just `openspec new change`.**
Rationale: `/opsx:propose <name>` (already used to build `orchestration-engine` and this very change) already produces all four artifacts in one invocation and is designed to be interactive (asks clarifying questions when needed) before returning control. This matches the engine's `await-approval` design intent: the human should see a complete proposal/design/specs package, not a bare directory scaffold, before approving.

**4. Spec Kit's propose section chains `/speckit.specify` → `/speckit.clarify` → `/speckit.plan` → `/speckit.tasks`, all before returning to the engine for `await-approval`.**
Rationale: matches the original design's Spec Kit workflow section (constitution/specify/clarify/plan/tasks) minus `/speckit.constitution` (project-level, done once outside any single cycle, not per-feature) and minus `/speckit.implement` (explicitly excluded project-wide — Superpowers owns implementation, per this project's own two-slash-command exclusion list). The reference file notes that if `.claude/dev-flow.config.json`'s target project has no constitution yet, that's a one-time project setup step outside this cycle, not something the engine should try to run per-feature.

**5. Spec Kit's archive section is a documented no-op, not an omitted section.**
The section exists (satisfying the engine's lookup) and its content states plainly: "Spec Kit has no archive concept; the feature's spec files under `specs/<feature>/` are the permanent record. No action is taken here." This is deliberate, not a gap — the alternative (silently having the engine special-case "if spec_tool is speckit, skip archive entirely") would put spec-tool-specific logic back in the engine, which is exactly what the naming-convention delegation was designed to avoid.

## Risks / Trade-offs

- [Risk] `/opsx:propose` and the Spec Kit chain are themselves multi-step, interactive flows (they may ask their own clarifying questions). If the underlying tool's interactivity conflicts with "don't stop mid-cycle," the Stop hook would force-continue even while, e.g., `/speckit.clarify` is mid-conversation with the user. → Mitigation: this is actually the intended design — `propose` is the one phase explicitly expected to involve back-and-forth before `await-approval`; the Stop hook only blocks *ending the turn*, not mid-turn tool use, so a genuinely multi-turn clarification exchange with the user during propose is compatible with the hook (each of the user's replies still lands inside the same non-terminal phase, and the hook only fires on stop attempts, not on every message).
- [Risk] If a project's `openspec/` or `specs/` directory structure ever changes upstream (OpenSpec or Spec Kit changing their own conventions), the hardcoded directory formulas in decision 2 would go stale silently. → Mitigation: out of scope for this change; both formulas match each tool's current, documented convention, and updating a reference file when an upstream tool changes its layout is a one-file edit, not an engine change.
- [Trade-off] Spec Kit's archive being a no-op means Spec Kit projects never get the delta-merge/sync benefits OpenSpec's archive step provides. Accepted — this mirrors the original project decision to treat Spec Kit as best for 0→1 greenfield work and OpenSpec as the long-term iteration tool; a project can migrate `spec_tool` from `speckit` to `openspec` later (documented in the original project notes, not in scope here).

## Migration Plan

Purely additive — two new files, no existing behavior changes. No rollback concerns beyond deleting the two files, which returns the engine to its current pause-on-missing-file state.

## Open Questions

- Should `/speckit.constitution` ever run automatically (e.g., on the very first cycle in a project with no constitution yet)? Leaning toward no — leave it a manual one-time project setup step outside `dev-flow`'s automated cycle — but flagging in case a future `installer` capability wants to prompt for it at install time.
