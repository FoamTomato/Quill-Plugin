# /quill:hld 编排

> 入口：`/quill:hld` / `/quill:hld-lite`
> 上游：已有 PRD（`/quill:prd` 或 `/quill:prd-lite` 产物均可）
> 下游：`/quill:dev`（dev 收工时回写 checklist）

---

## 产物

| 命令 | 路径 | 子 Agent | 形态 |
|---|---|---|---|
| `/quill:hld` | `${QUILL_PRD_DIR}/high-level-design.md` | `hld-writer-full` | 9 段完整 HLD + 详细伪代码 + 4 类 checklist |
| `/quill:hld-lite` | `${QUILL_PRD_DIR}/high-level-design.md` | `hld-writer-lite` | 实现速记：目标 + 粗略步骤 + **关键流程伪代码** + 极小 checklist（无接口表/SQL/4类checklist） |

> ⚠️ 两个命令产物**同一路径**：后跑的覆盖先跑的（full 与 lite 互为不同详细度的同一份 HLD）。

---

## 主 Agent 铁律

1. **前置检查 PRD 存在**，不存在则报错让用户先 `/quill:prd[-lite]`
2. **不 Read HLD 全文塞上下文**，只引路径
3. **不调 prd-writer-full / flow-writer**

---

## Phase 0 · 软探测输入（full / lite 同一套回退链，缺前置不报错退出）

两个命令都按优先级找来源，**绝不 exit**：full PRD > prd-lite 精炼需求 `requirement-*.md` > `$ARGUMENTS` 口述。

```bash
# 1) full PRD 最佳；2) prd-lite 精炼需求 requirement-*.md；3) $ARGUMENTS 口述
PRD="$QUILL_PRD_DIR/product-requirements.md"
RESOLVED=""
if [ -f "$PRD" ]; then
    RESOLVED="$PRD"
else
    RESOLVED=$(ls -1t "$QUILL_PRD_DIR"/requirement-*.md 2>/dev/null | head -1)
fi
REQ_TEXT="$ARGUMENTS"   # 口述兜底
if [ -z "$RESOLVED" ] && [ -z "$REQ_TEXT" ]; then
    # 不退出：提示并询问一句话需求
    echo "ℹ️ 暂无 PRD / requirement / 口述需求 —— 请用一句话说明要设计什么（或先跑 /quill:prd[-lite]）"
fi
```

差异只在「期望详细度」：
- **full（`/quill:hld`）**：推荐 full PRD；若只拿到 `requirement-*.md` / 口述，**照常产 9 段完整 HLD**，缺的细节标 `<TODO 用户补>`，并在文首标一致性提示。
- **lite（`/quill:hld-lite`）**：任一来源都按「实现速记」产出。

---

## Phase 1 · 调 hld-writer-full / hld-writer-lite（单次调用一把出）

**full 模式**：

```
Agent(
  subagent_type="hld-writer-full",
  description="Write HLD",
  prompt="""prd=$RESOLVED              # full PRD 或 requirement-*.md，可空
req_text=$REQ_TEXT                  # $ARGUMENTS 口述需求，可空（prd 为空时的来源）
hld_path=$QUILL_PRD_DIR/high-level-design.md
project_name=$QUILL_PROJECT_NAME
use_skills=$USE_SKILLS
"""
)
```

**lite 模式**（传 Phase 0 解析出的来源；`prd` 与 `req_text` 至少一个非空）：

```
Agent(
  subagent_type="hld-writer-lite",
  description="Write HLD Lite",
  prompt="""prd=$RESOLVED              # full PRD 或 requirement-*.md 路径，可空
req_text=$REQ_TEXT                  # $ARGUMENTS 口述需求，可空
hld_path=$QUILL_PRD_DIR/high-level-design.md
project_name=$QUILL_PROJECT_NAME
use_skills=$USE_SKILLS
"""
)
```

`use_skills=1` 时两种 writer 都先 `skill-pick hld <主题>` 检索设计规范 skill（harness，full 取正文 / lite 只瞄一眼）作 §八 伪代码与 §九 checklist 的准绳；`use_skills=0`（默认）纯模板写。子 agent 返回 `HLD_PATH=<绝对路径>`。

主 Agent 转用户 → 等 `确认` / `修改：...`。

---

## Phase 2 · 收尾

1. 给用户讲解（≤ 8 行）：
   - full：模块数 + 接口数 + DB 变更 + 灰区
   - lite：目标一句 + 步骤数 + 关键流程数（不数接口/DB，lite 不枚举它们）
2. 更新 `QUILL.md`：
   - 能力清单 `/quill:hld` 或 `/quill:hld-lite` 状态 ✅
   - 产物 checklist `high-level-design.md` 打勾（lite 标注 `(lite)`）
   - 最近活动 append 一行
3. 询问下一步：
   - `/quill:flow` — 画流程图
   - `/quill:dev` — 开干（dev 会按 checklist 回写）

---

## 绝对禁止

- ❌ 调 prd-writer-full / flow-writer
- ❌ 让 hld-writer-full 默认走分步
- ❌ lite 跑完自动跑 full（需要完整 HLD 请主动跑 `/quill:hld`）
