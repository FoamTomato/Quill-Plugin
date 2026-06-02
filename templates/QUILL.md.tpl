# QUILL · 能力清单与完成度

> 这是 Quill plugin 维护的索引文件。**不要手工修改**，由 `/quill *` 命令自动同步。
> CLAUDE.md 不会被 plugin 修改。

**项目**：{{PROJECT_NAME}}
**PRD 目录**：`{{PRD_DIR}}/`
**私有目录**：`.quill/`（gitignore 自动排除）

## 能力清单

**文档**（5 个独立命令，单次调用一把出）：

| 命令 | 作用 | 状态 |
|---|---|---|
| `/quill:prd`      | 完整 PRD（9 段详细）                    | ⏳ |
| `/quill:prd-lite` | 需求精炼（检索上下文 → 短需求文档）    | ⏳ |
| `/quill:hld`      | 完整 HLD（含详细伪代码 + 4 类 checklist） | ⏳ |
| `/quill:hld-lite` | 精简 HLD（实现步骤 + 关键流程伪代码）  | ⏳ |
| `/quill:flow`     | 业务流程图（3-6 张 draw.io，网格布局）  | ⏳ |

**开发与测试**：

| 命令 | 作用 | 状态 |
|---|---|---|
| `/quill:ui`       | UI 风格 skill 工厂（扫描/选/总结 → 存可复用 skill） | ⏳ |
| `/quill:dev`      | 多批次开发编排（默认不测）             | ⏳ |
| `/quill:dev-lite` | skill 驱动开发（核心 skill 5-16 个），不强制 PRD | ⏳ |
| `/quill:test`     | 三维测试（PRD/UI/Lint，支持 git-diff 模式） | ⏳ |
| `/quill:test-lite`| 核心轻量测试（只测未提交改动）         | ⏳ |
| `/quill:run`      | 动态编排器（auto-judge 进度，≤3 并发）  | ⏳ |

状态符号：⏳ 未跑 / 🟡 进行中 / ✅ 已完成 / ⚠️ 需要更新

## 产物完成度

- [ ] `{{PRD_DIR}}/product-requirements.md`     — 完整 PRD（机器可读源）
- [ ] `{{PRD_DIR}}/requirement-*.md`            — prd-lite 精炼需求（轻量链路）
- [ ] `{{PRD_DIR}}/high-level-design.md`        — HLD（含完成度 checklist）
- [ ] `{{PRD_DIR}}/flow.drawio`                 — 流程图（draw.io desktop 打开）
- [ ] `~/.claude/quill-skills/skills/style/*/`  — UI 风格 skill（/quill:ui 产出，dev 复用）
- [ ] 至少 1 个 `.quill/runs/<BATCH_ID>/` 收工（dev + test 全 PASS）

## 最近活动

（agent 自动 append，最多保留 10 行）

## 如何继续

**文档**：
- 写 PRD：`/quill:prd`（完整详细）/ `/quill:prd-lite`（需求精炼，产 requirement-*.md）
- 写 HLD：`/quill:hld`（完整）/ `/quill:hld-lite`（实现步骤 + 关键伪代码）
- 画流程：`/quill:flow`（支持 `--no-prd` 从 CLAUDE.md 推断）

**UI 风格**：
- `/quill:ui` — 扫描/选/总结风格 → 存成可复用 style skill，dev 自动用

**开发与测试**：
- 开发：`/quill:dev`（多批次，默认不测）/ `/quill:dev-lite [任务] [--review]`（skill 驱动，核心 skill 5-16 个，不强制 PRD）
- 测试：`/quill:test [--batch <ID>]`（完整三维，支持 git-diff）/ `/quill:test-lite`（核心轻量，只测未提交改动）
- 智能编排：`/quill:run`（auto-judge 进度，动态调度 planner/dev/test，≤3 并发）

**工具**：
- 升 skill：`/quill:update-skills`
