## 1. OpenSpec reference file

- [ ] 1.1 Create `skills/dev-flow/references/spec-tool-openspec.md` with `## propose 阶段做什么` section: drive `/opsx:propose <feature>` to completion, state the spec directory formula `openspec/changes/<feature>/`
- [ ] 1.2 Add `## archive 阶段做什么` section to the same file: drive `/opsx:archive` for the current feature
- [ ] 1.3 Write a structural test (`tests/spec_tool_openspec_test.sh`) asserting the file exists and both required section headers are present verbatim, plus that it mentions `/opsx:propose`, `/opsx:archive`, and the `openspec/changes/` directory formula

## 2. Spec Kit reference file

- [ ] 2.1 Create `skills/dev-flow/references/spec-tool-speckit.md` with `## propose 阶段做什么` section: drive `/speckit.specify` → `/speckit.clarify` → `/speckit.plan` → `/speckit.tasks` in order, state the spec directory formula `specs/<feature>/`, and note that `/speckit.constitution` is a one-time manual project setup step outside this cycle (not run automatically)
- [ ] 2.2 Add `## archive 阶段做什么` section to the same file: document the no-op explicitly (no command run, `specs/<feature>/` is the permanent record), engine still advances to `done`
- [ ] 2.3 Write a structural test (`tests/spec_tool_speckit_test.sh`) asserting the file exists and both required section headers are present verbatim, plus that it mentions all four Spec Kit commands in order, the `specs/` directory formula, and does NOT mention `/speckit.implement` or instruct running `/speckit.constitution` automatically

## 3. Cross-file consistency check

- [ ] 3.1 Write a test (`tests/spec_tool_adapter_consistency_test.sh`) that greps both reference files and asserts: both contain exactly the same two section headers (`## propose 阶段做什么`, `## archive 阶段做什么`); neither file references the other tool's commands (`spec-tool-openspec.md` must not mention `/speckit.*`, `spec-tool-speckit.md` must not mention `/opsx:*`)
- [ ] 3.2 Run all three new test files together and confirm pristine pass output
- [ ] 3.3 Cross-check every requirement in `specs/spec-tool-adapter/spec.md` has a corresponding test assertion above; fill any gaps
