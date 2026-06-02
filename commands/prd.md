---
description: Quill · 产品需求文档（只产 PRD，单次调用一把出；HLD/flow 拆为独立命令）
argument-hint: "[Issue # | 文件路径 | 自由文本 | 空] [--with-skills] [--remote-skills]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:prd · 产品需求文档

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

> ⚡ **只产 PRD 一件**（详细 markdown 文档，不产 HTML）。HLD / flow 是独立命令 `/quill:hld` `/quill:flow`。
> prd-writer-full **单次调用一把写完**。
> 只想把一句话需求理清、不需要完整 PRD → 用 `/quill:prd-lite`（需求精炼器）。
> 想让 PRD 写作参考 skill 规范库（harness）→ 带 `--with-skills`；想先拉远程最新 skill 再参考 → 带 `--remote-skills`。**默认不检索 skill（纯模板，快）。**

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行环境保护 + 配置 bootstrap + skill 校验。如果 `NEEDS_FIRST_RUN`，问完用户 PRD 目录、写完 config、再继续。

## Step 1.5 · 解析 skill 开关（用户决定要不要检索）

```bash
USE_SKILLS=0
case "$ARGUMENTS" in *--with-skills*|*--remote-skills*) USE_SKILLS=1 ;; esac
# --remote-skills：检索前先拉远程最新 skill 库（复用 skill-update.sh）
case "$ARGUMENTS" in *--remote-skills*) bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-update.sh ;; esac
```
把 `--with-skills` / `--remote-skills` 从 `$ARGUMENTS` 剥离后，剩下的才是需求入口。

## Step 2 · 走 PRD 编排

Read `${QUILL_SKILL_DIR}/prompts/prd-production.md`，按其执行：

1. **Phase 0** — 把剥离 flag 后的 `$ARGUMENTS` 归一化到 `$QUILL_PRIVATE_DIR/cache/source.md`（空入口走澄清三连）
2. **Phase 1** — 调 `prd-writer-full` **单次**，**把 `use_skills=$USE_SKILLS` 传给它**（=1 才检索写作规范 skill；=0 纯模板），一把写完整份 PRD
3. **Phase 2** — 收尾：更新 QUILL.md，AskUserQuestion 多选下一步

**⚠️ 要点**：
- prd-writer-full 不走 subagent-loop（不分步），单次调用必须出文件
- **不调 hld-writer-full / flow-writer**（各自是独立命令）

## Step 3 · 下一步提示（AskUserQuestion 多选）

收尾时给用户：
- `/quill:hld` — 产完整 HLD（含 checklist，dev 必读）
- `/quill:hld-lite` — 产精简 HLD（实现步骤 + 关键伪代码，原型场景）
- `/quill:flow` — 画业务流程图
- `/quill:ui` — 定义/提炼项目 UI 风格 skill
- `/quill:dev` — 直接开干（如果 PRD §四 API 契约已足够）

## 铁律

1. 主 Agent 不写 PRD 正文（澄清追问除外）
2. 不调 hld-writer-full / flow-writer
3. 不走大纲共识 Phase
4. prd-writer-full 单次调用
