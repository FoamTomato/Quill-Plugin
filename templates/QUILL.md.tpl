# QUILL · 能力清单与完成度

> 这是 Quill plugin 维护的索引文件。**不要手工修改**，由 `/quill *` 命令自动同步。
> CLAUDE.md 不会被 plugin 修改。

**项目**：{{PROJECT_NAME}}
**PRD 目录**：`{{PRD_DIR}}/`
**私有目录**：`.quill/`（gitignore 自动排除）

## 能力清单

| 命令 | 作用 | 状态 |
|---|---|---|
| `/quill prd`  | 理解需求 / 边界整理 / 给用户讲解        | ⏳ |
| `/quill ui`   | 前端 UI 设计（sketch + spec）          | ⏳ |
| `/quill dev`  | 多批次开发编排（默认链式 test）        | ⏳ |
| `/quill test` | 三维并发测试（PRD / UI / Lint）        | ⏳ |

状态符号：⏳ 未跑 / 🟡 进行中 / ✅ 已完成 / ⚠️ 需要更新

## 产物完成度

- [ ] `{{PRD_DIR}}/product-requirements.md`     — PRD 唯一机器可读源
- [ ] `{{PRD_DIR}}/high-level-design.md`        — HLD（含完成度 checklist）
- [ ] `{{PRD_DIR}}/flow.drawio`                 — 流程图（draw.io desktop 打开）
- [ ] `{{PRD_DIR}}/sketch/index.html`           — UI 原型导航页
- [ ] `{{PRD_DIR}}/ui-spec.md`                  — UI 规约（dev 消费）
- [ ] 至少 1 个 `.quill/runs/<BATCH_ID>/` 收工（dev + test 全 PASS）

## 最近活动

（agent 自动 append，最多保留 10 行）

## 如何继续

- 重写 PRD：`/quill prd`（已有 PRD 时会询问 覆盖/追加/格式化）
- 做前端：`/quill ui`
- 开发：`/quill dev`（默认链式 `/quill test`，`--no-test` 跳过）
- 只测：`/quill test [--batch <ID>]`
- 升 skill：`/quill update-skills`
