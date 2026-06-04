---
description: Quill · 概要设计（精简版：粗略实现步骤 + 关键流程伪代码，不含接口表/SQL/4类checklist）
argument-hint: "[需求文字（无 PRD 时直接当输入）] [--with-skills] [--remote-skills]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:hld-lite · 实现速记

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

> ⚡ 产「实现速记」：① 一句话目标 ② 粗略实现步骤 ③ 关键流程伪代码（中文）④ 极小 checklist。
> 不含完整接口表 / SQL DDL / 4 类 checklist / PRD 一致性比对 —— 那是 `/quill:hld`（full）的活。
> 上游可吃：full PRD、prd-lite 精简需求 `requirement-*.md`、或直接 `$ARGUMENTS` 里的口述需求（都没有才报错）。

> 想让伪代码参考 skill 设计规范（harness）→ 带 `--with-skills`；先拉远程最新 → `--remote-skills`。**默认不检索。**

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行。

## Step 1.5 · 解析 skill 开关

```bash
USE_SKILLS=0
case "$ARGUMENTS" in *--with-skills*|*--remote-skills*) USE_SKILLS=1 ;; esac
case "$ARGUMENTS" in *--remote-skills*) bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-update.sh ;; esac
```
剥离两个 flag 后剩下的才是需求文字。

## Step 2 · 走 HLD 编排（lite 模式）

Read `${QUILL_SKILL_DIR}/prompts/hld-production.md`，按其 **lite 分支**执行：

1. **Phase 0（lite 放宽）** — 找输入来源，优先级：full PRD > prd-lite 精简需求 `requirement-*.md` > `$ARGUMENTS` 口述需求；三者全无才报错
2. **Phase 1** — 调 `hld-writer-lite` **单次**（传解析出的 `prd` / `req_text` + `use_skills=$USE_SKILLS`），一把写完实现速记
3. **Phase 2** — 收尾：更新 QUILL.md（标 `(lite)`），提示下一步

## Step 3 · 下一步提示

- `/quill:hld` — 需要完整 HLD（接口表 / SQL / 4 类 checklist）时用
- `/quill:flow` — 画流程图
- `/quill:dev-lite` / `/quill:dev` — 开干

## 铁律

1. 主 Agent 不写 HLD 正文
2. 不调 prd-writer-full / flow-writer / hld-writer-full（full）
3. lite 必须含「关键流程伪代码」；不得退化成纯清单或塞接口表/SQL
4. 三种输入来源全无才报错让用户先 `/quill:prd[-lite]` 或带上需求文字
