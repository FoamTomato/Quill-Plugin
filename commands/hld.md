---
description: Quill · 概要设计文档（完整版，含 checklist + 详细伪代码）
argument-hint: "[--with-skills] [--remote-skills]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:hld · 概要设计（完整版）

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

> 产 9 段完整 HLD + 详细伪代码 + 4 类完成度 checklist。dev 收工时回写 `- [x]`。
> 只要「实现步骤 + 关键流程伪代码」、不要接口表/SQL/4类checklist → 用 `/quill:hld-lite`。

> 想让 HLD 参考 skill 设计规范库（harness）→ 带 `--with-skills`；想先拉远程最新 skill → 带 `--remote-skills`。**默认不检索（纯模板，快）。**

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行。

## Step 1.5 · 解析 skill 开关

```bash
USE_SKILLS=0
case "$ARGUMENTS" in *--with-skills*|*--remote-skills*) USE_SKILLS=1 ;; esac
case "$ARGUMENTS" in *--remote-skills*) bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-update.sh ;; esac
```
把两个 flag 从 `$ARGUMENTS` 剥离后，剩下的才是需求文字。

## Step 2 · 走 HLD 编排

Read `${QUILL_SKILL_DIR}/prompts/hld-production.md`，按其执行：

1. **Phase 0（软探测）** — 输入来源优先级：full PRD > prd-lite 精炼需求 `requirement-*.md` > `$ARGUMENTS` 口述；三者全无才提示补需求。**不强制 PRD**（完整 HLD 推荐 full PRD，但缺了会按可得来源尽力产，并在文首标一致性提示）
2. **Phase 1** — 调 `hld-writer-full` **单次**，**传 `use_skills=$USE_SKILLS`**，一把写完
3. **Phase 2** — 收尾：更新 QUILL.md，提示下一步

**⚠️ hld-writer-full 默认单次调用**（不走 subagent-loop）。

## Step 3 · 下一步提示

- `/quill:flow` — 画流程图
- `/quill:ui` — 前端 UI
- `/quill:dev` — 开干（按 checklist 回写）

## 铁律

1. 主 Agent 不写 HLD 正文
2. 不调 prd-writer-full / flow-writer
3. 无 PRD 不报错退出，按 requirement-*.md / 口述兜底产 HLD（缺段标提示）
