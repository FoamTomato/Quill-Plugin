# quill-plugin

Claude Code plugin · **单一职责拆分的研发流命令集 + 动态编排器** for any project.

跑一次 `claude plugin install`，在任意项目里以 ≤ 1 个问题的代价跑通：需求理解 / 概要设计 / UI 风格 / 多批次开发 / 测试。

## 命令总览

每个命令**职责单一、互不强耦合**：缺前置产物不报错，按可得来源降级运行。

### 文档生产

每个命令**只产 1 件**，全部 **单次调用一把出**。

| 入口 | 产物 | 何时用 |
|---|---|---|
| `/quill:prd`      | `product-requirements.md`（完整 9 段详细） | 正式项目、需要 API 契约 / DB schema |
| `/quill:prd-lite` | `requirement-<slug>.md`（需求精炼：检索现有上下文 → 2 段短需求文档） | 一句话需求、想结合现有项目说清再开干 |
| `/quill:hld`      | `high-level-design.md`（9 段 + 详细伪代码 + 4 类 checklist） | 多人协作、dev 需要回写 checklist |
| `/quill:hld-lite` | `high-level-design.md`（实现步骤 + 关键流程伪代码 + 极小 checklist） | 单人开发、快速原型 |
| `/quill:flow`     | `flow.drawio`（3-6 张业务流程图，40px 网格布局） | 业务流程需要可视化、给非技术干系人看 |

依赖关系：`/quill:hld` 需先跑过 `/quill:prd`；`/quill:hld-lite` 可吃 full PRD / prd-lite 精简需求 / 口述文字；`/quill:flow` 支持 `--no-prd` 从 CLAUDE.md / README 推断。

### UI 风格

| 入口 | 作用 |
|---|---|
| `/quill:ui` | **UI 风格 skill 工厂**：扫描现有代码 / 选内置风格 / 总结自有风格 → 存成可复用 `style/<slug>` skill，dev 写前端时自动复用 |

### 开发与测试

| 入口 | 作用 |
|---|---|
| `/quill:dev`      | 多批次开发编排（planner + dev；**默认不测**，`--then-test` 才链式） |
| `/quill:dev-lite` | skill 驱动开发（核心 skill **5-25 个**），**不强制 PRD**，`--review` 自检 |
| `/quill:test`     | 三维测试（PRD/UI/Lint）；无批次时走 **git-diff 模式**测未提交改动 |
| `/quill:test-lite`| 核心轻量测试（只测未提交改动，无批次/无回修 loop） |
| `/quill:run`      | **动态编排器**：auto-judge 进度，动态调度 planner/dev/test，≤3 子 agent 并发 |

### 工具命令

| 入口 | 作用 |
|---|---|
| `/quill:update-skills` | 升级 skill bundle（保留用户改过的文件） |
| `/quill:uninstall`     | 卸载 |

## Install

### 推荐：通过 marketplace（公网用户用这个）

```bash
# 1. 注册 marketplace（这条仓库即是 marketplace）
claude plugin marketplace add https://github.com/FoamTomato/Quill-Plugin

# 2. 安装
claude plugin install quill@quill

# 3. 后续升级
claude plugin update quill
```

### 本地开发（plugin 作者自己用）

```bash
# 把本地路径当 marketplace（一样 add，但走文件协议）
claude plugin marketplace add ~/个人项目/other/quill-plugin
claude plugin install quill@quill
```

## <a name="uninstall"></a>Uninstall

在任意已用过 quill 的项目里：

```bash
You> /quill:uninstall              # 列清单 + y/N 确认，清当前项目产物
You> /quill:uninstall --yes        # 跳过确认（脚本化场景）
You> /quill:uninstall --global     # 额外清 ~/.claude/quill-skills/（skill 缓存）
You> /quill:uninstall --dry-run    # 只看清单不动文件
```

默认清理范围（仅当前项目）：
- `.quill/`（私有运行产物，已 gitignore）
- `.quill-config.json`、`QUILL.md`（团队共享配置 / 能力索引）
- `.gitignore` 中由首跑追加的 Quill 块（精确 3 行匹配，不动用户手写的同名 ignore）

加 `--global` 额外清：`~/.claude/quill-skills/` 全局 skill bundle 缓存（**所有项目共享**，删了下次运行会自动重下）。

收尾自动调：`claude plugin uninstall quill` + `claude plugin marketplace remove quill`。CLI 不在 PATH 时改为打印手动命令。

## Quickstart

进入任意 git 项目（无 setup）：

```
You> /quill:prd

# 首次运行：plugin 问 1 个问题（PRD 输出目录）
# 选 docs/prd/<project>/（推荐）后：
#   - 自动写 .quill-config.json（push 进 git，团队共享）
#   - 自动下 skill bundle 到 ~/.claude/quill-skills/
#   - 自动在项目根写 QUILL.md（能力清单 + 完成度看板）
#   - 自动追加 .gitignore：.quill/
#
# 然后按需逐步产出：PRD → HLD → flow → UI 风格 → dev → test（每步独立，缺前置不报错）

You> /quill:ui      # UI 风格 skill 工厂：存成可复用 style skill
You> /quill:dev     # 多批次开发（默认不测）
You> /quill:test    # 三维测试（或 /quill:test-lite 测未提交改动）
You> /quill:run     # 也可：动态编排器，按进度自动调度 planner/dev/test
```

## 设计哲学

- **零提问首跑**：只问 PRD 路径，其他全自动。`.quill-config.json` 入 git，团队成员零提问。
- **本地私有产物**：`.quill/` 隐藏目录自动 gitignore，不污染主项目。
- **共享产物 git 化**：PRD/HLD/flow 落到用户指定可见路径。
- **Plugin 薄壳**：agent 模板 + 编排 prompt 都在 skill bundle，远端发更新即生效，不必重发 plugin。
- **CLAUDE.md 零侵入**：不改用户 CLAUDE.md，新增 QUILL.md 作为能力索引（agent 主动读）。
- **Skill 暗盒**：skill 不预加载、不落盘，单任务用完即弃。
- **用户改动保护**：`/quill:update-skills` 比对 sha256 跳过用户改过的文件。

## 文件结构

```
quill-plugin/
├── .claude-plugin/
│   ├── marketplace.json         # marketplace 清单（仅 1 个 plugin）
│   └── plugin.json              # plugin manifest
├── commands/                    # 每个 .md = 一个 /quill:<name> slash command
│   ├── prd.md                   # /quill:prd        — 完整 PRD
│   ├── prd-lite.md              # /quill:prd-lite   — 需求精炼器
│   ├── hld.md                   # /quill:hld        — 完整 HLD
│   ├── hld-lite.md              # /quill:hld-lite   — 实现步骤 + 关键伪代码
│   ├── flow.md                  # /quill:flow       — 业务流程图
│   ├── ui.md                    # /quill:ui         — UI 风格 skill 工厂
│   ├── dev.md                   # /quill:dev        — 多批次开发（默认不测）
│   ├── dev-lite.md              # /quill:dev-lite   — skill 驱动开发（5-25 个）
│   ├── test.md                  # /quill:test       — 三维测试（含 git-diff 模式）
│   ├── test-lite.md             # /quill:test-lite  — 核心轻量测试
│   ├── run.md                   # /quill:run        — 动态编排器
│   ├── update-skills.md         # /quill:update-skills
│   └── uninstall.md             # /quill:uninstall
├── hooks/
│   ├── hooks.json               # SubagentStop 注册
│   └── quill-subagent-stop.sh   # 收集 agent ID
├── lib/                         # 实质代码（不通过 skill bundle 发）
│   ├── config-bootstrap.sh      # 读配置
│   ├── config-write.sh          # 首跑：写 config + QUILL.md + gitignore
│   ├── skill-bootstrap.sh       # 首次下载 skill bundle
│   ├── skill-update.sh          # 增量更新（含用户改动保护）
│   ├── build-skill-index.sh     # skills/ → index/*.json
│   ├── skill-pick.sh            # 按阶段 + 主题选 skill（支持 --min/--max）
│   ├── skill-match.sh           # 按文件路径反查 skill（支持 --min/--max）
│   ├── skill-get.sh             # 取 skill 全文
│   └── quill-detect.sh          # 进度探针（/quill:run 的 auto-judge 数据源）
├── agents-src/                  # agent 模板（打包进 skill bundle，命名 <阶段>-<角色>[-<变体>]）
│   ├── prd-writer-full.md       # 完整 PRD
│   ├── prd-writer-lite.md       # 需求精炼器（产 requirement-*.md）
│   ├── hld-writer-full.md       # 完整 HLD（9 段 + 伪代码）
│   ├── hld-writer-lite.md       # 精简 HLD（步骤 + 关键伪代码）
│   ├── flow-writer.md           # 横向泳道时序图（一泳道=一模块，填色=实现状态）
│   ├── ui-style-author.md       # UI 风格 skill 工厂
│   ├── dev-planner.md           # 拆批次 + 设计指引 + skill 路径
│   ├── dev-coder.md             # 多批次写代码 + 回写 checklist
│   ├── test-tester-prd.md       # PRD/HLD 一致性测试
│   ├── test-tester-ui.md        # UI 视觉冒烟测试
│   ├── test-tester-lint.md      # 类型/lint 测试
│   └── _step-protocol.md        # 子 agent 分步执行契约（共享，不注册为 agent）
├── prompts-src/                 # 编排 prompt（打包进 skill bundle）
│   ├── prd-production.md
│   ├── prd-lite-production.md    # 需求精炼编排
│   ├── hld-production.md         # full（严格）+ lite（回退链）
│   ├── ui-style.md              # UI 风格 skill 工厂编排
│   ├── orchestrate.md           # /quill:run 路由大脑（R0-R9 + 并发协议）
│   └── 4-agent-orchestration.md # dev/test 内循环（默认不链式 test）
└── templates/
    └── QUILL.md.tpl
```

## Skill bundle 来源

skill 库本体维护在独立仓库 [Prompts-MCP](https://github.com/foamtomato/prompts-mcp)。

| 渠道 | 用途 |
|---|---|
| GitHub `foamtomato/prompts-mcp` | skill 真源 + PR 评审 |
| `xiaohang.site/skills/` | 人浏览 + plugin 自动更新分发源 |
| `~/.claude/quill-skills/` | 用户本地缓存（plugin 运行时唯一源） |
