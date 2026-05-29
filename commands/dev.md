---
description: Quill · 多批次开发编排（planner → dev loop → 默认链式 test）
argument-hint: "[Issue # | 自由文本] [--no-test]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:dev · 开发编排

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行**环境保护 + 配置 bootstrap + skill 校验**。

## Step 2 · 前置校验

```bash
[ -f "$QUILL_PRD_DIR/product-requirements.md" ] || { echo "❌ 缺 PRD，请先 /quill:prd"; exit 1; }
[ -f "$QUILL_PRD_DIR/high-level-design.md" ] || { echo "❌ 缺 HLD，请先 /quill:prd"; exit 1; }
```

## Step 3 · 走 4-Agent 编排

Read `${QUILL_SKILL_DIR}/prompts/4-agent-orchestration.md`，按其编排算法执行：

1. **Phase 0** — 初始化：生成 `BATCH_ID = <yymmdd>-<short>-<seq2>`，`mkdir -p .quill/runs/$BATCH_ID/test-reports/{prd,ui,lint}`
2. **Phase 1** — planner 一次性产 dev-plan / page-design-guide / skill-paths
3. **Phase 2** — 对每批 N：dev 主循环 + 同回复内并发 3 tester + FAIL ≤ 3 轮回修
4. **Phase 3** — 收工：更新 QUILL.md，可选 `gh pr create --fill`

## Step 4 · 默认链式 test

如果 `$ARGUMENTS` 不含 `--no-test`，dev 全 batch 收工后**自动**进入 `/quill:test` 流程（同会话内继续，不需要用户手动调）。

## 铁律

1. 主 Agent 不 Edit/Write 源码（必经 quill-dev sub-agent）
2. 上下文整洁 — 子 agent 间只传路径 + PASS/FAIL
3. DEV_ID 不跨批复用
4. tester 报告只 `head -1` 看判定
