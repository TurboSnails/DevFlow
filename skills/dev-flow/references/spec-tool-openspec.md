# spec-tool: openspec

供 `dev-flow` 引擎在项目配置文件(`lib/state.sh` 的 `config_file()`,
默认 `.codeflow/dev-flow.config.json`)的 `spec_tool` 配置为
`"openspec"` 时,在 propose 和 archive 阶段查阅。

## propose 阶段做什么

1. 执行 `/opsx:propose <feature>`,驱动到全部完成(proposal.md、
   design.md、specs/**/*.md、tasks.md 四个 artifact 都生成)。
   `<feature>` 使用运行状态里 `feature` 字段的值。
2. 该命令本身可能会向用户提出澄清问题——这是 propose 阶段设计上
   允许的交互,不违反"阶段之间不停顿"的规则,因为整个 propose 阶段
   本来就是在等待进入 `await-approval` 之前的正常工作过程。
3. 完成后,本轮循环的 spec 目录是:

   ```
   openspec/changes/<feature>/
   ```

   后续 `plan` 阶段基于这个目录生成实施计划。

## archive 阶段做什么

执行 `/opsx:archive`,把当前 `<feature>` 对应的 change 归档(delta 合并
回 `openspec/specs/`)。归档完成后,引擎照常把 `phase` 设为 `done`。
