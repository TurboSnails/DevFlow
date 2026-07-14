## 1. `/dev-flow:start`

- [ ] 1.1 Create `commands/dev-flow/start.md`: take feature name from `$ARGUMENTS`, invoke the `dev-flow` skill to start a new cycle for that feature (no state-file logic duplicated here)
- [ ] 1.2 Write a structural test (`tests/cli_start_test.sh`) asserting the file exists, references `$ARGUMENTS`, and instructs invoking the `dev-flow` skill rather than describing `state_init`/phase logic directly

## 2. `/dev-flow:stop`

- [ ] 2.1 Create `commands/dev-flow/stop.md`: source `lib/state.sh`, read `feature`/`phase` if the state file exists, delete the state file, report the phase reached; if no state file exists, report nothing to stop and take no action
- [ ] 2.2 Write a test (`tests/cli_stop_test.sh`) that actually exercises the command's logic against a real temp state file (not just structural grep) — simulate both branches (state file present, state file absent) and confirm deletion + correct reporting content

## 3. `/dev-flow:status`

- [ ] 3.1 Create `commands/dev-flow/status.md`: source `lib/state.sh`, read and report `feature`/`phase`/`blocks` if the state file exists, without modifying it; report no active cycle otherwise
- [ ] 3.2 Write a test (`tests/cli_status_test.sh`) exercising both branches against a real temp state file, confirming the file is unchanged after a status check

## 4. `/dev-flow:update`

- [ ] 4.1 Create `commands/dev-flow/update.md`: check for `install.sh` at the project root; if present, run it; if absent, report plainly that the installer isn't available yet and take no action
- [ ] 4.2 Write a test (`tests/cli_update_test.sh`) exercising both branches (an `install.sh` fixture present vs. absent in a temp directory), confirming the graceful-degradation behavior is documented and would be followed

## 5. Cross-cutting check

- [ ] 5.1 Write a test (`tests/cli_commands_no_autotrigger_test.sh`) asserting all four new command files live under `commands/dev-flow/` (not under any `skills/` directory) — a `description:` field is fine and expected (matches this repo's other command files), the invariant being checked is file placement, not field presence
- [ ] 5.2 Run all five new test files together with the full existing suite and confirm pristine pass output, no regressions
- [ ] 5.3 Cross-check every requirement in `specs/cli-commands/spec.md` has a corresponding test assertion above; fill any gaps
