---
description: Quill · 三维并发测试（PRD / UI / Lint），FAIL ≤ 3 轮回修
argument-hint: "[--batch <BATCH_ID>]"
allowed-tools: Bash, Read, Glob, Grep, Task
---

# /quill:test · 三维并发测试

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行**环境保护 + 配置 bootstrap + skill 校验**。

## Step 2 · 归一 artifacts 来源（编排层职责，tester 只收文件列表）

```bash
# 优先从 $ARGUMENTS 取 --batch <ID>，否则用 .quill/runs/ 下最新的
BATCH_ID=""
if echo "$ARGUMENTS" | grep -qE '\-\-batch [^ ]+'; then
    BATCH_ID=$(echo "$ARGUMENTS" | sed -E 's/.*--batch ([^ ]+).*/\1/')
fi
[ -z "$BATCH_ID" ] && BATCH_ID=$(ls -1t "${QUILL_PRIVATE_DIR}/runs/" 2>/dev/null | head -1)
DEV_OUTPUT="${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-output.md"

if [ -n "$BATCH_ID" ] && [ -f "$DEV_OUTPUT" ]; then
    # 批次来源：从 dev-output.md 解析 artifacts
    ARTIFACTS=$(awk '/^- artifacts:/{f=1;next} f&&/^  - /{print $2} f&&/^- /&&!/^- artifacts:/{f=0}' "$DEV_OUTPUT" | sort -u)
    DEV_OUTPUT_ARG="$DEV_OUTPUT"   # 供 prd tester checklist 命中校验
    AUTH_ARG="${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/authorized-paths.txt"   # 授权校验单一来源
else
    # 未提交改动来源
    ARTIFACTS=$( { git diff --name-only; git diff --cached --name-only; } 2>/dev/null | sort -u )
    [ -z "$ARTIFACTS" ] && { echo "✅ 无批次产物，也无未提交改动 —— 没东西可测。"; exit 0; }
    DEV_OUTPUT_ARG=""             # 无 dev-output → prd tester 跳过 checklist 命中校验
    AUTH_ARG=""                   # 无授权清单 → prd tester 退回 PRD「涉及目录」段
    BATCH_ID="gitdiff-$(date +%y%m%d)"
    echo "ℹ️ 测以下未提交改动："; echo "$ARTIFACTS"
fi
```

## Step 3 · 走测试编排

Read `${QUILL_SKILL_DIR}/prompts/4-agent-orchestration.md` 的 **「/quill test 独立路径」** 段，执行：

1. 同一回复内并发启动 3 个 tester，**一律传 `artifacts=$ARTIFACTS`**（tester 不知来源、不读 dev-output、不跑 git）
   - test-tester-prd 额外收 `prd_path` / `hld_path` / 可选 `authorized_paths_path=$AUTH_ARG` / 可选 `dev_output_path=$DEV_OUTPUT_ARG`
   - test-tester-ui 额外收可选 `ui_spec`
2. 只读首行 `### 判定：PASS|FAIL`
3. FAIL → 有批次且有 DEV_ID（`agent-ids.json`）则 resume 回修 ≤3 轮；纯未提交改动（无 dev agent）则只报告、不自动回修
4. 收工：更新 QUILL.md

**⚠️ 每个 tester / dev resume 调用必须按 `@${CLAUDE_PLUGIN_ROOT}/lib/subagent-loop.md` 循环驱动**（每次只跑一步）。phase 名：`tester-{prd,ui,lint}-batch-<N>`、`dev-batch-<N>`。3 个 tester 的循环可在主 Agent 端并发推进。

## 铁律

- 永远不 Read tester 报告全文（只 `head -1`）
- 同会话同维度 tester 用同一 agentId resume（省 token）
