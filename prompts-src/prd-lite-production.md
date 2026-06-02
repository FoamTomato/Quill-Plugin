# /quill:prd-lite 编排（需求精炼）

> 入口：`/quill:prd-lite`
> 上游：bootstrap 已就绪，`$QUILL_PRD_DIR` / `$QUILL_PROJECT_NAME` / `$QUILL_PRIVATE_DIR` 已 export
> 下游：`/quill:dev-lite`（轻量开发）/ `/quill:hld-lite`；如要完整 PRD 跑 `/quill:prd`
> 定位：**需求精炼器** —— 检索现有项目上下文 → 把用户口述需求细化成一份很短的可执行需求文档。**不是精简 PRD。**

---

## 产物（只 1 件）

| 路径 | 子 Agent | 形态 |
|---|---|---|
| `${QUILL_PRD_DIR}/requirement-<slug>.md` | `prd-writer-lite` | Markdown，**2 段**（需求 / 验收），基于现有上下文精炼 |

**不产**：`product-requirements.md`（那是 `/quill:prd`）、HLD、flow.drawio、UI、API 契约、DB schema。

---

## 主 Agent 铁律

1. **不写需求正文**（除澄清三连追问外）
2. **不 Read 全文塞上下文**，只引路径
3. **不做检索**（检索在 prd-writer-lite 内部）
4. **不调 hld-writer-full / flow-writer / ui-style-author**

---

## Phase 0 · 入口归一化

把需求种子统一落盘到 `${QUILL_PRIVATE_DIR}/cache/source.md`。

| 入口 | 触发形态 | 主 Agent 动作 |
|---|---|---|
| ① 本地需求文档 | 文件路径 | `cp <path> $QUILL_PRIVATE_DIR/cache/source.md` |
| ② GitHub Issue | issue 号或 URL | `gh issue view <n> --comments > $QUILL_PRIVATE_DIR/cache/source.md` |
| ③ 用户口述 | 自然语言 | 走「澄清三连」追问后落盘 |
| ④ 空入口 | `/quill:prd-lite` 无参 | 走「澄清三连」 |

**澄清三连**（口述 / 空入口必走，**只问 3 个问题**）：
1. 给「谁」用？解决什么痛点？
2. 走完核心场景的「一句话剧本」？
3. 怎么算「做完了」？有没有明确**不做**的事？

回答完落盘 source.md，**不需要用户二次确认**（lite 模式重在快）。

---

## Phase 1 · 调 prd-writer-lite（单次调用一把写完）

```
Agent(
  subagent_type="prd-writer-lite",
  description="Refine requirement",
  prompt="""project_name=$QUILL_PROJECT_NAME
requirement_dir=$QUILL_PRD_DIR
source=$QUILL_PRIVATE_DIR/cache/source.md
plugin_root=$CLAUDE_PLUGIN_ROOT
"""
)
```

prd-writer-lite **单次调用必须产出文件**：内部先**检索现有上下文**（现有 PRD/README + grep 代码 + skill-match），再**精炼**用户口述需求，写 `requirement-<slug>.md`。不分步、不返回 "STEP X DONE"。

主 Agent 收到 `REQUIREMENT_PATH=...` → 直接进 Phase 2。slug 冲突时 prd-writer-lite 会自己 AskUserQuestion（覆盖 / 换 slug / 取消）。

---

## Phase 2 · 收尾

1. 给用户 ≤ 4 行讲解（需求一句 + 复用到的现有面数 + 验收条数）
2. 更新 `QUILL.md`：
   - 能力清单 `/quill:prd-lite` 状态 ✅
   - 最近活动 append 一行（注明 `requirement-<slug>.md`）
3. 询问下一步：
   - `/quill:dev-lite` — 直接轻量开发（推荐）
   - `/quill:hld-lite` — 先出实现速记（步骤 + 伪代码）
   - `/quill:prd` — 需要完整 PRD（API 契约 / DB schema / 流程图）时用

---

## 绝对禁止

- ❌ 写 / 覆盖 `product-requirements.md`（解除与 `/quill:prd` 的文件耦合）
- ❌ 走大纲共识 Phase（那是 `/quill:prd` 的事）
- ❌ 调 hld-writer-full / flow-writer / ui-style-author
- ❌ 让 prd-writer-lite 分步执行
- ❌ 主 Agent 自己做检索 / Read 全文回显给用户
