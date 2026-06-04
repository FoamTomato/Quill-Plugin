# /quill:prd 编排（只产 PRD）

> 入口：`/quill:prd`
> 上游：bootstrap 已就绪，`$QUILL_PRD_DIR` / `$QUILL_PROJECT_NAME` / `$QUILL_PRIVATE_DIR` 已 export
> 下游：`/quill:hld`（HLD）/ `/quill:flow`（流程图）/ `/quill:ui`（UI 风格）/ `/quill:dev`（开发）

---

## 要点

- **只产 PRD 一件**，HLD / flow 是独立命令 `/quill:hld` `/quill:flow`
- 主 Agent 直接调 prd-writer-full，**不走大纲共识**
- **prd-writer-full 单次调用一把出**，仅特殊场景 `mode=stepwise`
- 必填段：§一-四 / §六 / §九；§五/七/八 按需

---

## 产物

| 路径 | 子 Agent | 形态 |
|---|---|---|
| `${QUILL_PRD_DIR}/product-requirements.md` | `prd-writer-full` | Markdown（§一-四/六/九 必填明细，§五/七/八 按需） |

---

## 主 Agent 铁律（三条）

1. **不写 PRD 正文**（除澄清三连追问外）
2. **不 Read PRD 全文塞上下文**，只引路径 + 一句话状态
3. **不调 hld-writer-full / flow-writer**，那是 `/quill:hld` / `/quill:flow` 的事

---

## Phase 0 · 入口归一化

把需求种子统一落盘到 `${QUILL_PRIVATE_DIR}/cache/source.md`。

| 入口 | 触发形态 | 主 Agent 动作 |
|---|---|---|
| ① 本地需求文档 | 文件路径 | `cp <path> $QUILL_PRIVATE_DIR/cache/source.md` |
| ② GitHub Issue | issue 号或 URL | `gh issue view <n> --comments > $QUILL_PRIVATE_DIR/cache/source.md` |
| ③ 用户口述 | 自然语言 | 走「澄清三连」追问后落盘 |
| ④ 空入口 | 无参 | 走「澄清三连」 |

**澄清三连**（口述 / 空入口必走，只问 3 个）：
1. 给「谁」用？解决什么痛点？
2. 走完核心场景的「一句话剧本」？
3. 怎么算「做完了」？有没有明确**不做**的事？

回答完落盘 source.md，**不需要用户二次确认**（重在快）。

---

## Phase 1 · 调 prd-writer-full（单次调用一把出）

```
Agent(
  subagent_type="prd-writer-full",
  description="Write PRD",
  prompt="""project_name=$QUILL_PROJECT_NAME
prd_path=$QUILL_PRD_DIR/product-requirements.md
source=$QUILL_PRIVATE_DIR/cache/source.md
mode_hint=auto
use_skills=$USE_SKILLS
"""
)
```

prd-writer-full 行为：
- `use_skills=1` 时写前先 `skill-pick prd <主题>` 检索 PRD 写作规范 skill（harness）作指导；`use_skills=0`（默认）纯模板写
- `prd_path` 不存在 → 新建（按 source + 模板写）
- `prd_path` 已存在 → AskUserQuestion：覆盖 / 追加 / 格式化
- 返回 `PRD_PATH=<绝对路径>`

主 Agent 收路径 → 转用户 → 等 `确认` / `修改：...`（修改触发再调一次 prd-writer-full 走 format 模式）。

---

## Phase 2 · 收尾

1. 给用户 ≤ 8 行讲解：背景一句 + 模块数 + 关键边界 + 待用户确认的灰区
2. 更新 `QUILL.md`：
   - 能力清单 `/quill:prd` 状态 ✅
   - 产物 checklist `product-requirements.md` 打勾
   - 最近活动 append 一行
3. 询问下一步（AskUserQuestion 多选）：
   - `/quill:hld` — 产 HLD（含完成度 checklist，dev 需要）
   - `/quill:flow` — 画流程图（用户视角的业务流程）
   - `/quill:ui` — 定义/提炼项目 UI 风格 skill
   - `/quill:dev` — 直接开干（如果 PRD §四 API 契约已经够细）

---

## 绝对禁止

- ❌ 写 `.outline.md` 走大纲共识 Phase
- ❌ 调 hld-writer-full / flow-writer（拆走了）
- ❌ 让 prd-writer-full 默认走分步（除非用户主动要 `mode=stepwise`）
- ❌ 逐段问用户「这段填啥」（prd-writer-full 应留 `<TODO>` 占位，不要回 AskUserQuestion）
