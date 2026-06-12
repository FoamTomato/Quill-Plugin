---
description: Quill · 业务流程图（draw.io XML 横向泳道时序图，3-6 张精简图）
argument-hint: "[--no-prd 强制走无 PRD 模式]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill:flow · 业务流程图（横向泳道时序图）

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

> 产 `.drawio` 文件，3-6 张**横向泳道时序图**（一条泳道=一个技术模块）。用户用 draw.io desktop 双击打开编辑。
>
> 取材三选一，由 flow-writer 落地：读 PRD/HLD（默认）/ 扫代码 / 读用户口述。绘图规则全在 flow-writer agent，主 Agent 只负责探测模式、调 agent、收尾。

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

**无 PRD 模式分支**：AskUserQuestion 询问用户「不要 PRD/HLD，直接产泳道时序图，素材怎么给？」：
- A. **扫代码 / 表结构自动推断**（`source=scan`）—— flow-writer 读 controller/service/entity/DDL/DTO，先列「推断的流程 + 参与者泳道(模块)」等用户确认再画
- B. **我口述需求直接画**（`source=dictation`）—— 主 Agent 把用户口述（谁调谁、走哪些步、涉及哪些表/入参）落到 `$QUILL_PRIVATE_DIR/cache/flow-source.md`，flow-writer 直接据此画、不二次确认
- C. 先跑 `/quill:prd` 再来画
- D. 取消

> 选 B 时主 Agent 先追问用户口述业务流程，写入缓存文件，再带 `flow_source=<缓存路径>` 调 flow-writer。

## Step 3 · 调 flow-writer（单次调用一把出）

```
Agent(
  subagent_type="flow-writer",
  description="Generate flow diagram",
  prompt="""flow_path=$FLOW
prd=$PRD                    # normal 模式传路径；no_prd 模式留空
hld=$HLD                    # 有则传，无则留空
source=<scan|dictation>    # 仅 no_prd 模式传：A→scan B→dictation
flow_source=<缓存路径>      # 仅 source=dictation 时传，指向用户口述缓存文件
"""
)
```

flow-writer 行为：
- **normal 模式**：读 PRD/HLD 一把出 3-6 张图
- **no_prd + source=scan**：先在 stdout 列推断的业务流程 + 参与者泳道清单 → 主 Agent 转用户确认 → 用户回 `确认` 后再次调 flow-writer 画图
- **no_prd + source=dictation**：直接读 `flow_source` 一把出图，**不二次确认**

**⚠️ flow-writer 默认单次调用一把出**（不走 subagent-loop）。

## Step 4 · 收尾

1. 给用户讲解：画了几张**泳道时序图**、关键流程是哪些；确认 `DIAGRAMS` 在 3-6 之间（某图泳道 >6 或 消息 >20 则回报可拆图微调）
2. 更新 `QUILL.md`：产物 checklist `flow.drawio` 打勾
3. 提示：用 draw.io desktop 打开 `${FLOW}` 编辑

## 铁律

1. 主 Agent 不画图，绘图规则全在 flow-writer，命令不复述。
2. 不调 prd-writer-full / hld-writer-full。
3. `source=scan` 必须等用户确认 flow-writer 列出的流程清单才画；`source=dictation` 直接画，不确认。
