---
name: "GS: Ship"
description: Commit, push, open a PR, and wait for CI — merging is a separate manual step
category: Workflow
tags: [workflow, gstack-bridge, ship]
---

Ship the current branch's pending changes: commit, push, open a pull
request, and wait for CI to finish. This command does NOT merge —
merging is always a separate, manual step the user performs later
(via the GitHub UI or GitHub's merge capability), so this command can run to
completion without needing a human checkpoint mid-way.

Steps:
1. Run `git status --short`. If there are uncommitted changes, stage
   and commit them with a Conventional Commits message describing the
   change.
2. Push the current branch: `git push -u origin HEAD`.
3. Create a pull request: `gh pr create --fill` (or with an explicit
   title/body if one was already drafted in this conversation).
4. Wait for CI to complete: `gh pr checks --watch` (or equivalent)
   until all checks finish.
5. Report the CI result (pass/fail, and which checks if any failed)
   to the user. Stop here — merging is always a separate manual step
   and never part of this command.

This command is what `dev-flow`'s `ship` phase (see
`skills/dev-flow/SKILL.md`) invokes by name. Because this command never
pauses for a merge decision, `dev-flow`'s Stop hook (which has no
knowledge of any pause point inside `ship`) can safely force
continuation once this command finishes — the engine advances straight
to `archive` once the PR is open and CI has reported, without waiting
for an actual merge.
