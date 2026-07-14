## 1. State file and shared helpers

- [ ] 1.1 Define `.claude/dev-flow-state.json` schema (`feature`, `phase`, `blocks`, `spec_tool`) as a documented example file in `lib/`
- [ ] 1.2 Implement `lib/state.sh` with functions to read the state file, write/update `phase`, increment `blocks`, and create the file with initial values
- [ ] 1.3 Write a unit-style test script that exercises `lib/state.sh` functions directly (create, read, update phase, increment blocks) without invoking Claude

## 2. Stop hook

- [ ] 2.1 Implement `hooks/dev-flow-gate.sh`: exit 0 if state file absent
- [ ] 2.2 Implement phase check: exit 0 (allow) if `phase` is `done`, `paused`, or `await-approval`
- [ ] 2.3 Implement block-cap check: exit 0 (allow) if `blocks >= 40`
- [ ] 2.4 Implement default path: increment `blocks`, emit `{"decision":"block","reason":...}` referencing current `phase`
- [ ] 2.5 Write test cases covering each branch (no state file, each pass-through phase, block-cap boundary, forced-block path) by invoking the script directly with fixture state files

## 3. dev-flow SKILL.md

- [ ] 3.1 Write `skills/dev-flow/SKILL.md` frontmatter (`name`, `description`) so it is the sole auto-triggering skill for development requests
- [ ] 3.2 Write cycle-start instructions: create state file with `phase=propose`, populate `feature` and `spec_tool` (from `.claude/dev-flow.config.json`)
- [ ] 3.3 Write per-phase instructions for `propose`, `plan`, `build`, `verify`, `ship`, `archive`, matching the sequence and delegation rules from design.md
- [ ] 3.4 Write the `await-approval` handling: present spec summary, wait for user approval, then advance to `plan`
- [ ] 3.5 Write the missing-delegation-file handling: if `references/spec-tool-<spec_tool>.md` doesn't exist, set `phase=paused` and ask the user to fix config instead of guessing
- [ ] 3.6 Write the verify-phase instructions: run `gate_command` if configured, invoke `/codex:review` if `codex_review` is true, require both to pass before advancing to `ship`

## 4. Verification against spec

- [ ] 4.1 Manually walk through a full mock cycle (fake `spec_tool` reference files, no-op `gate_command`) end-to-end confirming state file transitions match the fixed sequence
- [ ] 4.2 Confirm Stop hook blocks at each non-exempt phase and allows stop at `await-approval` and `done` during the walkthrough
- [ ] 4.3 Confirm the 40-block safety cap releases the stop by simulating `blocks=39` and one more forced attempt
- [ ] 4.4 Cross-check every requirement in `specs/orchestration-engine/spec.md` has a corresponding manual test step above; fill any gaps
