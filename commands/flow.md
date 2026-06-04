---
description: Quill · 业务流程图（draw.io XML，3-6 张精简图）
argument-hint: "[--no-prd 强制走无 PRD 模式]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:flow · 业务流程图

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

> 产 `.drawio` 文件，3-6 张精简业务流程图。用户用 draw.io desktop 双击打开编辑。
>
> 支持两种模式：
> - **有 PRD/HLD**（默认）：从 PRD §二 / HLD §八 派生流程
> - **无 PRD 模式**（`--no-prd` 或 PRD 不存在）：从 CLAUDE.md / README 推断业务流程

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行。

## Step 2 · 探测模式

```bash
PRD="$QUILL_PRD_DIR/product-requirements.md"
HLD="$QUILL_PRD_DIR/high-level-design.md"
FLOW="$QUILL_PRD_DIR/flow.drawio"

NO_PRD_FLAG=0
case "$ARGUMENTS" in *--no-prd*) NO_PRD_FLAG=1 ;; esac

if [ "$NO_PRD_FLAG" = "1" ] || [ ! -f "$PRD" ]; then
    MODE=no_prd
else
    MODE=normal
fi
```

**无 PRD 模式分支**：AskUserQuestion 询问用户：
- A. flow-writer 从 CLAUDE.md / README / 项目结构自动推断（先列推断的流程清单等用户确认再画）
- B. 用户口述业务流程，主 Agent 落到 `$QUILL_PRIVATE_DIR/cache/flow-source.md`
- C. 先跑 `/quill:prd` 再来画
- D. 取消

## Step 3 · 调 flow-writer（单次调用一把出）

```
Agent(
  subagent_type="flow-writer",
  description="Generate flow diagram",
  prompt="""prd=$PRD                  # 可能为 ""，触发无 PRD 模式
hld=$HLD
flow_path=$FLOW
mode=<normal|no_prd>
layout=grid40              # 强制 40px 网格、正交折线、5-9 节点/图、节点不重叠
"""
)
```

flow-writer 行为：
- **normal 模式**：读 PRD/HLD 一把出 3-6 张图
- **no_prd 模式**：先在 stdout 列推断的业务流程清单 → 主 Agent 转用户确认 → 用户回 `确认` 后再次调 flow-writer 画图

**⚠️ flow-writer 默认单次调用一把出**（不走 subagent-loop）。

## Step 4 · 收尾

1. 给用户讲解：画了几张图、关键流程是哪些；确认 `DIAGRAMS` 在 3-6 之间（某图节点 >12 或 <4 则回报可微调）
2. 更新 `QUILL.md`：产物 checklist `flow.drawio` 打勾
3. 提示：用 draw.io desktop 打开 `${FLOW}` 编辑

## 铁律

1. 主 Agent 不画图
2. 不调 prd-writer-full / hld-writer-full
3. **无 PRD 模式必须等用户确认推断的流程清单才画图**
