---
description: Quill · 理解需求 / 整理边界 / 产 PRD + HLD + flow.drawio
argument-hint: "[Issue # | 自由文本]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:prd · PRD 生产

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行**环境保护 + 配置 bootstrap + skill 校验**。如果 `NEEDS_FIRST_RUN`，必须问完用户 PRD 目录、写完 config、再继续 Step 2。**不要中断**。

## Step 2 · 走 PRD 编排

Read `${QUILL_SKILL_DIR}/prompts/prd-production.md`，按其编排执行：依次启动 3 个子 agent —
1. `prd-writer`（自动识别 新建/覆盖/追加/格式化 模式）
2. `hld-writer`（产 high-level-design.md，含完成度 checklist）
3. `flow-writer`（产 flow.drawio）

**⚠️ 调子 agent 必须按 `@${CLAUDE_PLUGIN_ROOT}/lib/subagent-loop.md` 循环驱动**（每个 sub-agent 单次只跑一步，主 Agent 循环再调直到 `ALL_DONE`，防止 socket 超时断开）。phase 名分别为 `prd-writer`、`hld-writer`、`flow-writer`。

## Step 3 · 收尾

- 给用户 < 10 行讲解（背景 + 关键边界 + 待用户确认的灰区）
- 更新项目根的 `QUILL.md`：`/quill:prd` 状态改 ✅，三件套打勾，append 活动日志
- 询问：「下一步：`/quill:ui` 画前端原型 / `/quill:dev` 开始开发？」

## 五条铁律（沿用 Quill）

1. 主 Agent 不写 PRD/HLD 正文（除大纲对齐外）
2. 不 Read 三份产物全文塞回上下文
3. 逐份用户确认，不替用户拍板
4. 强制大纲共识才进 Phase 2
5. 时序日志 append 到 `${QUILL_PRIVATE_DIR}/logs/prd-log.md`
