---
name: dev-flow
description: 本项目所有开发任务的唯一自动触发入口。用户提出任何代码相关
  需求(修 bug、加功能、重构、改 UI、性能优化),或调用 /dev-flow:start
  时使用。驱动 propose → await-approval → plan → build → verify → ship
  → archive → done 全流程自动推进,阶段之间不停顿、不询问,直到完成或
  用户明确要求停止。这是本项目里唯一允许自动触发的技能——所有其它
  CodeFlow 能力(gs/* 等)都是普通 command,不会自动触发,不会与本技能
  抢触发权。
---

# dev-flow: 自动推进的开发工作流引擎

## 状态文件

所有运行状态存在 `.claude/dev-flow-state.json`,字段:`feature`、
`phase`、`blocks`、`spec_tool`。通过 `lib/state.sh` 提供的函数读写,
不要直接用 jq/cat 手改这个文件:

- `state_init <feature> <spec_tool>` — 开始新一轮循环时调用一次
- `state_get <field>` — 读取字段
- `state_set_phase <phase>` — 切换到下一阶段时调用
- `state_increment_blocks` — 由 Stop hook 自己调用,skill 不需要手动调

这些函数定义在 `lib/state.sh` 里,每个 Bash 工具调用都是一个全新的
shell,函数不会跨调用保留。因此每次调用状态函数,必须和
`source lib/state.sh` 在同一次 Bash 调用里(或者当前 shell 已经
source 过),例如:

```bash
source lib/state.sh && state_set_phase "plan"
```

以上所有操作都假定当前工作目录是项目根目录(`lib/state.sh` 的默认状态
文件路径和 source 路径都是相对路径)。

## 阶段序列(固定,不可跳过或重排)

```
propose → await-approval → plan → build → verify → ship → archive → done
```

## 启动新一轮循环

收到开发需求(或用户执行 `/dev-flow:start <功能名>`)时:

1. 读取 `.claude/dev-flow.config.json` 的 `spec_tool` 字段(缺省视为
   `"openspec"`)
2. 执行 `state_init "<功能名>" "<spec_tool>"`,此时 `phase` 自动为
   `propose`
3. 进入 propose 阶段(见下)

## 各阶段动作

### propose
读取当前 `spec_tool`,查找 `skills/dev-flow/references/spec-tool-<spec_tool>.md`。

- **文件存在**:按该文件里 "propose 阶段做什么" 一节的指示生成 spec。
  完成后执行 `state_set_phase "await-approval"`,展示 spec 摘要,结束
  这一轮回复(Stop hook 在 `await-approval` 阶段会放行,不会强制续跑)。
- **文件不存在**:不要猜测或跳过。执行 `state_set_phase "paused"`,
  向用户说明 `spec_tool` 配置的值没有对应的 reference 文件,请用户
  修正 `.claude/dev-flow.config.json` 后再继续。

### await-approval
等待用户批准(用户说"批准/继续/ok"等)。收到批准后执行
`state_set_phase "plan"`,进入 plan 阶段。用户若要求修改 spec,留在
`await-approval`,不要自行推进。

### plan
基于 propose 阶段产出的 spec 目录,使用 Superpowers 的 writing-plans
技能生成实施计划。完成后执行 `state_set_phase "build"`。

### build
按 writing-plans 产出的计划,使用 Superpowers 的 TDD 技能逐任务执行
(子代理隔离)。全部任务完成后执行 `state_set_phase "verify"`。

### verify
1. 读取 `.claude/dev-flow.config.json` 的 `gate_command` 字段:
   - 非空:执行该 shell 命令,必须成功(exit 0)才能继续;失败则修复
     后重试,不要跳过。
   - 为空或不存在:跳过这一步。
2. 读取 `codex_review` 字段(布尔):
   - 为 `true`:调用 `/codex:review --base main`,处理 BLOCKED 反馈后
     重跑,直至通过。
   - 为 `false` 或不存在:跳过这一步。
3. 两步都通过后执行 `state_set_phase "ship"`。

### ship
调用 `/gs:ship`(只按命令名调用,不关心其内部实现)。成功后执行
`state_set_phase "archive"`。

### archive
再次查找 `skills/dev-flow/references/spec-tool-<spec_tool>.md`,按该
文件里 "archive 阶段做什么" 一节的指示归档 spec。完成后执行
`state_set_phase "done"`。

- **文件不存在**:和 propose 阶段一样,不要猜测或跳过。执行
  `state_set_phase "paused"`,向用户说明 `spec_tool` 配置的值没有对应
  的 reference 文件,请用户修正 `.claude/dev-flow.config.json` 后再
  继续。

## 用户要求停止

用户在任意阶段说"停止/暂停/stop"时,调用 `/dev-flow:stop`(会删除状态
文件)并汇报当前完成到哪一步,然后结束回复。除此之外,以及除
`await-approval` 阶段外,不要主动停下来"汇报进度"或"询问是否继续"——
Stop hook 会把这类提前结束强制拦截推回。
