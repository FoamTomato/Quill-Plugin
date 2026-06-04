---
description: Quill · 核心轻量测试（只测未提交改动，主 Agent 直接跑，无批次/无 3 维并发/无 3 轮回修）
argument-hint: "[--fix 仅提示不自动修]"
allowed-tools: Bash, Read, Glob, Grep, Task
---

# /quill:test-lite · 核心轻量测试

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

> ⚡ 极简测试：只测**未提交改动**的核心功能点。
> 没有 BATCH_ID、没有 3 维并发、没有 3 轮回修 loop。与 `/quill:dev-lite` 配套。
> 想要完整三维测试（PRD/UI/Lint + 回修）→ 用 `/quill:test`。

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行环境保护 + 配置 bootstrap。

## Step 2 · 取未提交改动

```bash
DIFF_FILES=$( { git diff --name-only; git diff --cached --name-only; } 2>/dev/null | sort -u )
[ -z "$DIFF_FILES" ] && { echo "✅ 无未提交改动，无需测试。"; exit 0; }
echo "测以下未提交改动："; echo "$DIFF_FILES"
# 改动目录（跑工具的范围）
DIFF_DIRS=$(echo "$DIFF_FILES" | xargs -n1 dirname 2>/dev/null | sort -u)
```

## Step 3 · 核心检查（主 Agent 直接跑，不开 sub-agent）

按改动文件类型 best-effort 跑（工具不存在就跳过）：

```bash
# JS/TS：改动目录有 package.json → npx tsc --noEmit / npx eslint <files>
# Python：有 pyproject.toml → ruff check <files> / mypy <files>
# 其他语言按 test-tester-lint 的桶规则类比
```

再对**核心功能点**做快速冒烟（仅当能低成本验证时）：
- 有现成单测覆盖改动 → 跑相关单测
- 前端改动且有 dev server → 起一下看关键页面不报错（可选，超时即跳过，不死等）

## Step 4 · 输出 punch list（≤10 行，不自动回修）

```
## test-lite 结果
- ✅ <PASS 项>
- ⚠️ <warning，不阻塞>
- ❌ <FAIL，建议修>
```

**不自动回修**。把 punch list 给用户，等用户决定（要修可回 `/quill:dev-lite` 改）。

## Step 5 · 收尾

更新 `QUILL.md`：能力清单 `/quill:test-lite` ✅、最近活动 append 一行。

## 铁律

1. **只测未提交改动**（git diff），不依赖 BATCH_ID
2. **不开 3 维并发、不做 3 轮回修 loop**（那是 `/quill:test`）
3. **不自动回修**，只出 punch list
4. 主 Agent 直接跑（轻量，不开 sub-agent）
