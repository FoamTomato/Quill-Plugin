---
description: Quill · 需求精炼（检索现有 PRD/代码上下文，把口述需求细化成一份很短的可执行需求文档；非完整 PRD）
argument-hint: "[Issue # | 文件路径 | 自由文本 | 空]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:prd-lite · 需求精炼器

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

> ⚡ 这是**需求精炼器**：你只有一句话需求，想结合现有项目把它说清楚再开干。
> 它会**先检索现有项目上下文（PRD/README/代码/skill）**，再把你的口述需求细化成一份**很短（2 段）的可执行需求文档** `requirement-<slug>.md`。
> 需要完整 PRD（模块明细 / API / DB）→ 用 `/quill:prd`。

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行环境保护 + 配置 bootstrap + skill 校验。如果 `NEEDS_FIRST_RUN`，问完用户 PRD 目录、写完 config、再继续。

## Step 2 · 走需求精炼编排

Read `${QUILL_SKILL_DIR}/prompts/prd-lite-production.md`，按其执行：

1. **Phase 0** — 把 `$ARGUMENTS` 归一化到 `$QUILL_PRIVATE_DIR/cache/source.md`（空入口走澄清三连）
2. **Phase 1** — 调 `prd-writer-lite` **单次**：内部先检索现有上下文 → 细化需求 → 产 `requirement-<slug>.md`
3. **Phase 2** — 收尾：更新 QUILL.md，提示下一步

**⚠️ 关键差异**：`prd-writer-lite` 不分步、单次调用必须出文件；产物是 `requirement-<slug>.md`，**不碰 `product-requirements.md`**。

## Step 3 · 下一步提示

收尾时给用户：
- `/quill:dev-lite` — 直接轻量开发（推荐，无需 HLD）
- `/quill:hld-lite` — 先出实现速记（步骤 + 伪代码）
- `/quill:prd` — 需要完整 PRD（模块明细 / API / DB）时用

## 铁律

1. 主 Agent 不写需求正文（澄清追问除外）
2. 主 Agent 不做检索（检索在 prd-writer-lite 内部）
3. 不调 hld-writer-full / flow-writer / ui-style-author
4. 不写 / 不覆盖 `product-requirements.md`
