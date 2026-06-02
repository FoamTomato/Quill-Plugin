---
description: Quill · 多批次开发编排（planner → dev loop；默认不测，--then-test 才链式 test）
argument-hint: "[Issue # | 自由文本] [--then-test]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:dev · 开发编排

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行**环境保护 + 配置 bootstrap + skill 校验**。

## Step 2 · 软探测输入（不强制，缺了走兜底）

**不报错退出**。按优先级探测需求/设计来源，传给 planner，缺啥就降级：

```bash
PRD="$QUILL_PRD_DIR/product-requirements.md"
HLD="$QUILL_PRD_DIR/high-level-design.md"
REQ=$(ls -1t "$QUILL_PRD_DIR"/requirement-*.md 2>/dev/null | head -1)

# 需求来源：full PRD > prd-lite 精炼需求 > $ARGUMENTS 口述
[ -f "$PRD" ] && SRC="$PRD" || SRC="$REQ"
[ -f "$HLD" ] && echo "📄 有 HLD，dev 会按 §九 checklist 回写" || echo "ℹ️ 无 HLD，planner 直接从需求拆批次（不回写 checklist）"
[ -z "$SRC" ] && [ -z "$ARGUMENTS" ] && echo "ℹ️ 无任何文档，将用 $ARGUMENTS 口述 / 询问一句话需求"
```

> 缺 PRD → planner 用 `requirement-*.md` 或口述需求拆批次。
> 缺 HLD → 照常开发，只是没有 checklist 可回写（planner 自行从需求/代码推断任务粒度）。
> 想要完整文档支撑 → 先跑 `/quill:prd[-lite]` / `/quill:hld[-lite]`，但**非强制**。

## Step 3 · 走 4-Agent 编排

Read `${QUILL_SKILL_DIR}/prompts/4-agent-orchestration.md`，按其编排算法执行：

1. **Phase 0** — 初始化：生成 `BATCH_ID = <yymmdd>-<short>-<seq2>`，`mkdir -p .quill/runs/$BATCH_ID/test-reports/{prd,ui,lint}`
2. **Phase 1** — planner 一次性产 dev-plan / page-design-guide / skill-paths / authorized-paths（授权范围单一来源，dev 与 tester-prd 同源；含 ≤6 batch 级 skill，dev 再逐任务 skill-match 反查）
3. **Phase 2** — 对每批 N：dev 主循环。**默认 `RUN_TEST=0`（不测）**；仅 `--then-test` 时才接 Step 2.2/2.3（3 tester 并发 + FAIL ≤3 轮回修）
4. **Phase 3** — 收工：更新 QUILL.md，可选 `gh pr create --fill`

**⚠️ 所有 sub-agent 调用必须按 `@${CLAUDE_PLUGIN_ROOT}/lib/subagent-loop.md` 循环驱动**（每次只跑一步）。phase 名：planner = `planner-<BATCH_ID>`，dev = `dev-batch-<N>`，tester = `tester-{prd,ui,lint}-batch-<N>`。dev step 3 会 return `WAITING_FOR_USER_CONFIRMATION` —— 这是 understanding 卡点，**必须把 understanding.md 路径列给用户，等用户回 `理解已确认` 再续循环**。

## Step 4 · 收尾与下一步（默认不测）

dev 全 batch 收工后**默认停手不测**（职责拆分）。给用户提示：
- 想测当前改动 → `/quill:test`（完整三维）或 `/quill:test-lite`（核心轻量）
- 想要自动按进度编排测试/多批 → `/quill:run`
- `--then-test`：本次跑完 dev 后链式跑测试（旧默认行为，现需显式开）

## 铁律

1. 主 Agent 不 Edit/Write 源码（必经 dev-coder sub-agent）
2. 上下文整洁 — 子 agent 间只传路径 + PASS/FAIL
3. DEV_ID 不跨批复用
4. tester 报告只 `head -1` 看判定
5. **默认不链式 test**；测试交 `/quill:test` / `/quill:test-lite` / `/quill:run`
