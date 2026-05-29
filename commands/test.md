---
description: Quill · 三维并发测试（PRD / UI / Lint），FAIL ≤ 3 轮回修
argument-hint: "[--batch <BATCH_ID>]"
allowed-tools: Bash, Read, Glob, Grep, Task
---

# /quill:test · 三维并发测试

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行**环境保护 + 配置 bootstrap + skill 校验**。

## Step 2 · 解析 batch

```bash
# 优先从 $ARGUMENTS 取 --batch <ID>
BATCH_ID=""
if echo "$ARGUMENTS" | grep -qE '\-\-batch [^ ]+'; then
    BATCH_ID=$(echo "$ARGUMENTS" | sed -E 's/.*--batch ([^ ]+).*/\1/')
fi
# 否则用 .quill/runs/ 下最新的
[ -z "$BATCH_ID" ] && BATCH_ID=$(ls -1t "${QUILL_PRIVATE_DIR}/runs/" 2>/dev/null | head -1)

[ -d "${QUILL_PRIVATE_DIR}/runs/$BATCH_ID" ] || {
    echo "❌ 批次 $BATCH_ID 不存在。先跑 /quill:dev 产生批次。"
    exit 1
}
[ -f "${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-output.md" ] || {
    echo "❌ 批次 $BATCH_ID 未跑过 dev (无 dev-output.md)"
    exit 1
}
```

## Step 3 · 走测试编排

Read `${QUILL_SKILL_DIR}/prompts/4-agent-orchestration.md` 的 **「/quill test 独立路径」** 段，执行：

1. 同一回复内并发启动 3 个 tester（quill-tester-prd / quill-tester-ui / quill-tester-lint）
2. 只读首行 `### 判定：PASS|FAIL`
3. FAIL → SendMessage resume DEV_ID（来自 `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/agent-ids.json`）→ 3 轮回修上限
4. 收工：更新 QUILL.md

## 铁律

- 永远不 Read tester 报告全文（只 `head -1`）
- 同会话同维度 tester 用同一 agentId resume（省 token）
