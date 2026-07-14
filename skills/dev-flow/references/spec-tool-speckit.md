# spec-tool: speckit

供 `dev-flow` 引擎在 `.claude/dev-flow.config.json` 的 `spec_tool`
配置为 `"speckit"` 时,在 propose 和 archive 阶段查阅。

## propose 阶段做什么

按顺序执行以下 Spec Kit 命令,`<feature>` 使用运行状态里 `feature`
字段的值:

1. `/speckit.specify` —— 生成功能规范
2. `/speckit.clarify` —— 逼问所有模糊点
3. `/speckit.plan` —— 技术方案(schema、API 契约、组件层级)
4. `/speckit.tasks` —— 任务清单

不要在这里运行 `/speckit.constitution`——它是项目级、一次性的宪法声明,
不属于单个功能的循环;项目首次接入 Spec Kit 时应该手动跑一次,而不是
由 dev-flow 自动触发。

完成后,本轮循环的 spec 目录是:

```
specs/<feature>/
```

后续 `plan` 阶段基于这个目录生成实施计划。

## archive 阶段做什么

Spec Kit 没有归档概念。`specs/<feature>/` 下的 spec 文件本身就是永久
记录,这里不执行任何命令。引擎照常把 `phase` 设为 `done`,视为循环
正常结束。
