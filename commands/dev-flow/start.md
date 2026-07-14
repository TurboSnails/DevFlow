---
name: "Dev Flow: Start"
description: Start a new dev-flow development cycle for a named feature
category: Workflow
tags: [workflow, dev-flow]
---

Start a new dev-flow development cycle.

**Input**: The argument after `/dev-flow:start` is the feature name
(kebab-case), e.g. `/dev-flow:start add-user-auth`. Use `$ARGUMENTS` as
the feature name.

Use the Skill tool to invoke the `dev-flow` skill, framing this as a
request to start a new development cycle for the feature named in
`$ARGUMENTS`. Do not perform state initialization or phase-sequencing
yourself here — `skills/dev-flow/SKILL.md` already fully specifies what
happens when a new cycle starts, including entering the `propose` phase.
This command's only job is to trigger that skill with the right feature
name.
