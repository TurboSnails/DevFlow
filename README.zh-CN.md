# CodeFlow

[English](README.md) | 简体中文

CodeFlow 把"spec → plan → build → verify → ship → archive"这套自动推进的开发工作流,打包成一个可以装进 Claude Code、Codex、Cursor 的技能/命令包。你只需要描述想做什么,`dev-flow` 技能就会从提案一路推进到可发布的 PR,不需要你在每个阶段之间手动再敲一次命令。整个循环只在一个地方暂停(等你批准 spec),其余时候会一直往下推,直到完成或者你叫它停。

## 为什么要做这个

主要解决两个问题:

1. **技能互相抢触发权。** 同时装几套自动触发的 agent 技能包(比如一套 TDD/规划工具 + 一套产品/运维工具)会导致多个技能同时想解释同一条需求。CodeFlow 全项目只留一个自动触发的技能(`dev-flow`),其它所有能力——包括它自己的控制命令,以及借调自 Gstack 风格的 ship/freeze/retro 命令——都是需要显式调用的普通 command。
2. **手动续跑太累。** 把 spec → plan → build → verify → ship 拆成五次手动操作,意味着每个阶段之间都要盯着会话续命。一个 Stop hook 会在助手想提前结束回合时强制它继续,直到真正到达一个该停的地方(`done`、`paused`,或者唯一刻意保留的 `await-approval` 暂停点)。

## 安装

```bash
git clone git@github.com:TurboSnails/DevFlow.git ~/.codeflow-src
cd /path/to/your-project
~/.codeflow-src/install.sh claude   # 或者: codex | cursor | all(默认 all)
```

之后想更新,重新跑一遍同样的命令即可(项目内也可以用 `/dev-flow:update` 触发,见下文)。`--dry-run` 只显示会装什么、会迁移什么,不实际写入任何文件:

```bash
~/.codeflow-src/install.sh --dry-run all
```

### 每个客户端具体装了什么

| 客户端 | 技能 | 控制命令 | `/gs:*` 命令 | 续跑强制机制 |
|---|---|---|---|---|
| **Claude Code** | `.claude/skills/dev-flow/` | `.claude/commands/dev-flow/{start,stop,status,update}.md` | `.claude/commands/gs/{ship,freeze,office-hours,retro,cso}.md` | 原生支持——靠真正的 Stop hook + PreToolUse hook 实现,注册在 `.claude/settings.json` 里 |
| **Codex** | `.codex/skills/dev-flow/` | ——(暂无命令面) | —— | 不支持——只能靠提示词引导,没有 hook 机制 |
| **Cursor** | `.cursor/skills/dev-flow/` | `.cursor/commands/dev-flow-{start,stop,status,update}.md` | `.cursor/commands/gs-{ship,freeze,office-hours,retro,cso}.md` | 不支持——只能靠提示词引导 |

只有 Claude Code 有真正的强制机制(Stop hook 强制续跑循环、PreToolUse hook 拦截对冻结路径的编辑)。Codex/Cursor 上装的技能和命令文字内容是一样的,但没有任何机制能真正阻止助手提前结束回合或编辑被冻结的文件——这两个客户端上,整套流程靠的是助手自觉遵守自己被给的指示。机器可读版本的这张对照表在 `config/client-capabilities.json`。

项目状态和配置统一放在 `.codeflow/` 目录下(不放在任何某个客户端自己的目录里),这样装了多个客户端时可以共用同一份状态/配置:`.codeflow/dev-flow-state.json`(运行时状态)和 `.codeflow/dev-flow.config.json`(项目配置,见下文)。如果你的项目里还留着更早版本的 `.claude/dev-flow-state.json` / `.claude/dev-flow.config.json`,安装器第一次运行时会自动帮你迁移过去。

## dev-flow 循环

```
propose → await-approval → plan → build → verify → ship → archive → done
```

- **propose**——生成 spec(走 OpenSpec 还是 Spec Kit,见下面"Spec 工具"一节),生成完就暂停。
- **await-approval**——唯一刻意保留的暂停点。看一眼 spec,回复批准,循环才会继续。
- **plan**——把批准过的 spec 转成一步步的实施计划(委托给 Superpowers 的 `writing-plans` 技能)。
- **build**——按计划逐任务实现,走 TDD。
- **verify**——跑你配置的 `gate_command`(测试/lint),可选再跑 `/codex:review`,两者都得通过。
- **ship**——调用 `/gs:ship`:commit、push、开 PR、等 CI、汇报结果。它从不合并——合并永远是你之后自己手动做的独立动作。
- **archive**——把 spec 归档(走 OpenSpec/Spec Kit),循环到达 `done`。

一个 Stop hook(`hooks/dev-flow-gate.sh`)会在助手想在 `await-approval`、`paused`、`done` 以外的任何地方结束回合时,强制它继续推进——每个阶段最多容忍 40 次强制续跑(阶段一旦切换,计数器就会清零,所以一个正常但耗时较长的 `build` 阶段不会被这个安全阀提前打断)。

## 命令

### `/dev-flow:*`——控制循环本身

| 命令 | 作用 |
|---|---|
| `/dev-flow:start <功能名>` | 显式启动一轮循环(效果和直接用大白话描述需求一样,技能本来就会自动触发) |
| `/dev-flow:stop` | 停止当前循环,并汇报它停在哪个阶段 |
| `/dev-flow:status` | 汇报 `feature`/`phase`/`blocks`,不改动任何东西 |
| `/dev-flow:update` | 针对当前客户端重新跑一遍安装器,刷新 dev-flow 相关文件 |

### `/gs:*` 和 `/office-hours`——其余的工具集

| 命令 | 作用 |
|---|---|
| `/gs:office-hours` | 写一个不算小的功能的 spec 之前,必须先回答的六个问题——这是产品思考层的关卡,不是代码 |
| `/gs:ship` | commit → push → PR → 等 CI → 汇报。从不合并。这就是 `ship` 阶段按名字调用的那个命令。 |
| `/gs:freeze <路径>` | 把一个路径声明为 AI 不得编辑,做法是把它追加进 `.claude/frozen-paths.txt`(纯文本,一行一个前缀——想解冻直接编辑这个文件删掉对应行) |
| `/gs:retro` | 结构化的周回顾对话(这周做了什么/卡在哪/下周计划) |
| `/gs:cso` | 针对当前分支改动的安全审计清单(密钥、权限变更、新依赖、是否碰了冻结区) |

在 Claude Code 上,`/gs:freeze` 是真的会被强制执行的:`hooks/freeze-gate.sh` 会拦截 Edit/Write/MultiEdit 调用,凡是目标路径落在某个冻结前缀下的都会被拦下。但它**不会**拦截 Bash 工具——冻结的文件依然可以被一条 shell 命令改掉,所以把"冻结"理解成对助手的强提示,而不是硬安全边界。

## 配置

`.codeflow/dev-flow.config.json`(需要你自己创建;没有任何机制会自动生成默认值):

```json
{
  "spec_tool": "openspec",
  "gate_command": "npm test",
  "codex_review": false
}
```

| 字段 | 取值 | 含义 |
|---|---|---|
| `spec_tool` | `"openspec"` \| `"speckit"` | 决定 `propose`/`archive` 两个阶段用哪个 spec 工具驱动。`openspec`:适合存量项目,delta 式提案,走 `/opsx:propose` / `/opsx:archive`。`speckit`:适合全新项目,依次走 `/speckit.specify` → `.clarify` → `.plan` → `.tasks`(没有归档步骤——Spec Kit 本身没有归档这个概念)。 |
| `gate_command` | 任意 shell 命令,或不填 | 在 `verify` 阶段执行,必须 exit 0 才能继续。不填就跳过这一步。 |
| `codex_review` | `true` \| `false` | `verify` 阶段是否额外跑 `/codex:review --base main`(需要装了 Codex CLI 插件)。 |

## 仓库结构(给想贡献代码的人看)

```
skills/dev-flow/SKILL.md              唯一自动触发的技能
skills/dev-flow/references/           spec_tool 委托目标(openspec/speckit)
lib/state.sh                          运行状态 + 配置路径的读写函数(state_init、state_get……)
hooks/dev-flow-gate.sh                Stop hook —— 强制循环继续
hooks/freeze-gate.sh                  PreToolUse hook —— 拦截对冻结路径的编辑
commands/dev-flow/*.md                /dev-flow:start|stop|status|update
commands/gs/*.md                      /gs:ship|freeze|office-hours|retro|cso
config/client-capabilities.json       机器可读的各客户端能力对照表
install.sh                            把以上内容安装/迁移进目标项目
tests/*.sh                            每个组件一个测试文件,可以单独直接跑
```

这里的每一个 capability 都走过 spec → design → plan → TDD 实现 → 代码审查这一整套流程才合并进来;当前的需求记录在 `openspec/specs/` 里,历史提案在 `openspec/changes/archive/` 里。

### 跑测试

```bash
for t in tests/*.sh; do bash "$t" || exit 1; done
```

每个测试文件都是自包含的(自己建临时状态/配置文件,跑完自己清理),也可以单独运行。
