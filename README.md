# quill-plugin

Claude Code plugin · **4-agent orchestration + PRD production** for any project.

跑一次 `claude plugin install`，在任意项目里以 ≤ 1 个问题的代价跑通：需求理解 / UI 原型 / 多批次开发 / 三维并发测试。

## 4 个能力（subcommand）

| 入口 | 作用 | 产物 |
|---|---|---|
| `/quill prd`  | 理解需求 + 整理边界 + 给用户讲解 | `product-requirements.md` / `high-level-design.md` / `flow.drawio` |
| `/quill ui`   | 前端 UI 设计                      | `sketch/*.html` + `ui-spec.md` |
| `/quill dev`  | 多批次开发编排（默认链式 test）   | `.quill/runs/<BATCH>/dev-output.md` |
| `/quill test` | 三维并发测试（PRD/UI/Lint）       | `.quill/runs/<BATCH>/test-reports/*` |
| `/quill update-skills` | 升级 skill bundle（保留用户改过的文件） | 更新 `~/.claude/quill-skills/` |

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

## Quickstart

进入任意 git 项目（无 setup）：

```
You> /quill prd

# 首次运行：plugin 问 1 个问题（PRD 输出目录）
# 选 docs/prd/<project>/（推荐）后：
#   - 自动写 .quill-config.json（push 进 git，团队共享）
#   - 自动下 skill bundle 到 ~/.claude/quill-skills/
#   - 自动在项目根写 QUILL.md（能力清单 + 完成度看板）
#   - 自动追加 .gitignore：.quill/
#
# 然后走 prd-writer → hld-writer → flow-writer 三连产出

You> /quill ui      # 产 sketch + ui-spec
You> /quill dev     # 多批次开发 → 默认链式 /quill test
You> /quill test    # 也能单独跑
```

## 设计哲学

- **零提问首跑**：只问 PRD 路径，其他全自动。`.quill-config.json` 入 git，团队成员零提问。
- **本地私有产物**：`.quill/` 隐藏目录自动 gitignore，不污染主项目。
- **共享产物 git 化**：PRD/HLD/flow 落到用户指定可见路径。
- **Plugin 薄壳**：agent 模板 + 编排 prompt 都在 skill bundle，远端发更新即生效，不必重发 plugin。
- **CLAUDE.md 零侵入**：不改用户 CLAUDE.md，新增 QUILL.md 作为能力索引（agent 主动读）。
- **Skill 暗盒**：skill 不预加载、不落盘，单任务用完即弃。
- **用户改动保护**：`/quill update-skills` 比对 sha256 跳过用户改过的文件。

## 文件结构

```
quill-plugin/
├── .claude-plugin/
│   ├── marketplace.json         # marketplace 清单（仅 1 个 plugin）
│   └── plugin.json              # plugin manifest
├── commands/
│   ├── quill.md                 # /quill 入口分发器（prd|ui|dev|test）
│   └── quill-update-skills.md
├── hooks/
│   ├── hooks.json               # SubagentStop 注册
│   └── quill-subagent-stop.sh   # 收集 agent ID
├── lib/                         # 实质代码（不通过 skill bundle 发）
│   ├── config-bootstrap.sh      # 读配置
│   ├── config-write.sh          # 首跑：写 config + QUILL.md + gitignore
│   ├── skill-bootstrap.sh       # 首次下载 skill bundle
│   ├── skill-update.sh          # 增量更新（含用户改动保护）
│   ├── build-skill-index.sh     # skills/ → index/*.json
│   ├── skill-pick.sh            # 按阶段 + 主题选 skill
│   ├── skill-match.sh           # 按文件路径反查 skill
│   └── skill-get.sh             # 取 skill 全文
├── agents-src/                  # 9 个 agent 模板（打包进 skill bundle）
│   ├── prd-writer.md
│   ├── hld-writer.md
│   ├── flow-writer.md
│   ├── ui-designer.md
│   ├── quill-planner.md
│   ├── quill-dev.md
│   ├── quill-tester-prd.md
│   ├── quill-tester-ui.md
│   └── quill-tester-lint.md
├── prompts-src/                 # 3 个编排 prompt（打包进 skill bundle）
│   ├── prd-production.md
│   ├── ui-design.md
│   └── 4-agent-orchestration.md
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

## Status

v0.2.0 (P1–P6 实现完成，P7 发布中)

- ✅ P1 骨架：plugin.json / commands / lib/config-*.sh / QUILL.md.tpl
- ✅ P2 Skill 暗盒：5 个 shell 脚本，index 三表
- ✅ P3 PRD 链路：prd-writer / hld-writer / flow-writer
- ✅ P4 UI 链路：ui-designer + antd MCP 集成
- ✅ P5 4-Agent 搬运：planner / dev / 3 tester 解耦
- ✅ P6 自动更新 + 用户改动保护
- 🔄 P7 团队复用 + 发布
