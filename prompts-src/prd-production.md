# /quill prd 编排（v2）

> 入口：`/quill prd`
> 上游：用户已通过 `commands/quill.md` 走完 bootstrap，环境变量 `$QUILL_PRD_DIR` / `$QUILL_PROJECT_NAME` / `$QUILL_PRIVATE_DIR` 已 export。
> 下游：`/quill ui`（前端原型）/ `/quill dev`（开发）的输入来源。

---

## 产物（v2，三件套）

| 件次 | 路径 | 子 Agent | 形态 | 谁读 |
|---|---|---|---|---|
| ① PRD | `${QUILL_PRD_DIR}/product-requirements.md` | prd-writer | **Markdown**（唯一机器可读源） | 人 + 所有下游 agent |
| ② HLD | `${QUILL_PRD_DIR}/high-level-design.md` | hld-writer | **Markdown**（含完成度 checklist） | 人 + planner / dev / tester-prd |
| ③ Flow | `${QUILL_PRD_DIR}/flow.drawio` | flow-writer | **draw.io XML**（双击 draw.io desktop 打开） | 人 |

> **重要**：sketch HTML 不在本流程产出，移到 `/quill ui`。本流程只产 3 个文件，PRD 自包含「涉及目录 / API 契约 / 数据库 schema」三段（dev/planner 唯一机器可读源）。

---

## 主 Agent 五条铁律（沿用 Quill）

1. 主 Agent **不写 PRD/HLD 正文**，不画 flow，不写 SQL（除大纲对齐阶段外）
2. **不 Read 三份产物全文塞回上下文**，只引路径 + 一句话状态
3. **逐份用户确认**，不替用户拍板
4. **强制大纲共识** 才进 Phase 2，否则三份文档大纲不一致
5. 时序日志 append 到 `${QUILL_PRIVATE_DIR}/logs/prd-log.md`

---

## Phase 0 · 入口归一化

主 Agent 把需求种子统一落盘到 `${QUILL_PRIVATE_DIR}/cache/source.md`。

| 入口 | 触发形态 | 主 Agent 动作 |
|---|---|---|
| ① 本地需求文档 | 文件路径 | `cp <path> $QUILL_PRIVATE_DIR/cache/source.md` |
| ② GitHub Issue | issue 号或 URL | `gh issue view <n> --comments > $QUILL_PRIVATE_DIR/cache/source.md` |
| ③ 用户口述 | 自然语言 | 用「澄清三连」追问后落盘 |

**澄清三连**（口述模式必走）：
1. 这个产品/功能是给「谁」用的？当前痛点？
2. 走完核心场景的「一句话剧本」？
3. 怎么算「做完了」？有没有明确**不做**的范围？

`source.md` 落盘前，用户必须回 "确认" 才进 Phase 1。

---

## Phase 1 · 大纲共识（强制卡点）

**已有 PRD 时跳过 Phase 0+1**，直接进 Phase 2 让 prd-writer 进入「自动识别模式」（覆盖 / 追加 / 格式化）。

无 PRD 时主 Agent 自起草大纲（**唯一允许主 Agent 写正文的环节**），落盘 `${QUILL_PRD_DIR}/.outline.md`（隐藏文件，共识完即可删 / 留作 changelog 锚点）。

模板：

```markdown
# <项目名> · 需求大纲（共识稿）

## 大模块清单
- M1 · <大模块名>：<一句话>
- M2 · ...

## 每个大模块的小模块
### M1
- M1.1 · <小模块>：<一句话>
- M1.2 · ...

## 前端页面清单（供 /quill ui 参考）
- P1 · <页面名>（属 M?）：<一句话用途>

## 后端能力清单（供 hld-writer 参考）
- A1 · <接口/能力>（属 M?）：<一句话>

## 涉及目录预估（供 prd-writer 落到 PRD）
- path/to/dir/: 用途
- ...
```

写完反馈用户：「大纲共识稿：`<path>`，回 `确认` / `修改：<点>`」。

**未确认前禁止进 Phase 2。**

---

## Phase 2 · 依序产出三份文档

### Step 2.1 · prd-writer（自动识别模式）

```
Agent(
  subagent_type="prd-writer",
  description="Write PRD",
  prompt="""project_name=$QUILL_PROJECT_NAME
prd_path=$QUILL_PRD_DIR/product-requirements.md
outline=$QUILL_PRD_DIR/.outline.md
source=$QUILL_PRIVATE_DIR/cache/source.md
mode_hint=auto    # auto / overwrite / append / format
"""
)
```

prd-writer 行为：
- `prd_path` 不存在 → 新建（按 outline 写）
- `prd_path` 已存在 → **询问用户**：覆盖重写 / 追加段 / 格式化已有手稿（保留语义，整成 PRD 结构）
- 返回 PRD 绝对路径

主 Agent 收路径 → 转发用户 → 等 `确认` / `修改：...` → SendMessage 改稿 → 确认。

### Step 2.2 · hld-writer（依赖 PRD 已确认）

```
Agent(
  subagent_type="hld-writer",
  description="Write HLD",
  prompt="""prd=$QUILL_PRD_DIR/product-requirements.md
hld_path=$QUILL_PRD_DIR/high-level-design.md
project_name=$QUILL_PROJECT_NAME
"""
)
```

产出 markdown 含**完成度 checklist**：每个 API / 表 / 模块一行 `- [ ]`。dev 收工时回写 `- [x]`。

### Step 2.3 · flow-writer（依赖 PRD + HLD）

```
Agent(
  subagent_type="flow-writer",
  description="Generate flow diagram",
  prompt="""prd=$QUILL_PRD_DIR/product-requirements.md
hld=$QUILL_PRD_DIR/high-level-design.md
flow_path=$QUILL_PRD_DIR/flow.drawio
"""
)
```

产出 draw.io XML 文件，**精简**（每个核心业务流程一张图，不啰嗦）。

---

## Phase 3 · 收尾

3.1 主 Agent 给用户 < 10 行讲解（背景 + 关键边界 + 待用户确认的灰区）
3.2 更新 `QUILL.md`：
- 「能力清单」`/quill prd` 状态改 ✅
- 「产物完成度」对应 3 行打勾
- 「最近活动」append 一行：`[YYMMDD HHMM] /quill prd 完成 → product-requirements.md / high-level-design.md / flow.drawio`
3.3 询问：「下一步：`/quill ui` 画前端原型 / `/quill dev` 开始开发？」

---

## QUILL.md 更新片段（agent 必读）

```bash
# 更新「能力清单」对应行
sed -i.bak 's|`/quill prd` .* ⏳|`/quill prd` ... ✅|' QUILL.md
# 更新产物 checklist
sed -i.bak "s|- \[ \] \`${QUILL_PRD_DIR}/product-requirements.md\`|- [x] \`${QUILL_PRD_DIR}/product-requirements.md\`|" QUILL.md
# (同理 hld.md / flow.drawio)
rm QUILL.md.bak
# append 活动日志
echo "- \`[$(date +'%y%m%d %H%M')] /quill prd 完成 → product-requirements.md / high-level-design.md / flow.drawio\`" \
  >> /tmp/quill_activity.tmp
# 主 Agent 用 Edit 把这一行插入 QUILL.md「最近活动」段
```

---

## 绝对禁止

- ❌ 跳过 Phase 1 大纲共识直接启动子 Agent（除非已有 PRD 走 prd-writer 自动识别）
- ❌ 主 Agent Read 三份产物全文
- ❌ 主 Agent 替用户拍板
- ❌ flow-writer 产 mermaid（要 draw.io XML，因为用户要用 draw.io desktop 改图）
- ❌ hld-writer 写真实代码语法（伪代码用中文步骤）
