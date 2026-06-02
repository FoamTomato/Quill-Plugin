---
description: Quill · 轻量开发（skill 驱动，无 planner / 无分批 / 无 tester；--review 触发自检）
argument-hint: "[Issue # | PRD 路径 | 自由文本 | 空] [--review]"
allowed-tools: Bash, Read, Write, Edit, MultiEdit, Glob, Grep, Task, AskUserQuestion, WebFetch
---

# /quill:dev-lite · 轻量开发

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

> ⚡ harness 极简：**理解 → skill 驱动写代码 → 可选自检**。
> 没有 planner、没有 BATCH_ID、没有 3 轮 tester loop、没有 state.json。
> 适合：原型、小功能、单文件改动、PoC、Issue 修复。
> 重链路（多批次 / 强测试）请用 `/quill:dev`。

## Step 1 · Bootstrap

按 `@${CLAUDE_PLUGIN_ROOT}/lib/bootstrap-instructions.md` 执行环境保护 + 配置 bootstrap + skill 校验。

**不强制 PRD 存在**。Bootstrap 完成即可继续。

## Step 2 · 解析参数

```bash
RUN_REVIEW=0
case "$ARGUMENTS" in
  *--review*) RUN_REVIEW=1 ;;
esac
```

把 `--review` 从 `$ARGUMENTS` 剥离，剩下的当作「任务输入」。

## Step 3 · 解析任务输入（4 种形态）

| 输入形态 | 主 Agent 动作 |
|---|---|
| ① 空 | AskUserQuestion 问「这次想改什么？」一句话搞定 |
| ② Issue # / Issue URL | `gh issue view <n> --comments` 读全文当任务说明 |
| ③ 文件路径（指向 PRD lite / .md） | Read 该文件当任务说明 |
| ④ 自由文本 | 直接当任务说明 |

**默认查需求文档但不强制**（优先 prd-lite 精炼需求，其次 full PRD）：
```bash
PRD="$QUILL_PRD_DIR/product-requirements.md"
REQ=$(ls -1t "$QUILL_PRD_DIR"/requirement-*.md 2>/dev/null | head -1)
[ -n "$REQ" ] && echo "📄 检测到精炼需求: $REQ（优先作为参考）"
[ -f "$PRD" ] && echo "📄 检测到 PRD: $PRD（作为参考，不强制）"
```
有 `requirement-*.md`（prd-lite 产物）或 PRD 就 Read 当参考，没有也能跑。

## Step 4 · Understand（主 Agent 自己干）

**禁止开 sub-agent**，主 Agent 自己执行：

1. 综合任务输入 + 项目结构（必要时 grep / glob 关键目录）
2. **检索核心 skill（数量夹在 [5,16]）**：从任务里抽关键词/改动文件 glob，调脚本（强制 min 5 / max 16）：
   ```bash
   # 按阶段 + 主题（含已检索到的项目风格 skill style/*）
   bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-pick.sh dev <主题关键字> --min 5 --max 16
   # 或按改动文件 glob + 关键词反查（含 applies_to 命中的 style/* 风格 skill）
   bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-match.sh "<file globs>" "<keywords>" --min 5 --max 16
   ```
   选出的 **5-16 个核心 skill** 列进理解卡；写代码时按需 Read 全文 / 调对应 Skill 工具。
3. 输出 ≤ 8 行的「理解卡」给用户：

```
## 我要改什么
- <bullet 1>
- <bullet 2>

## 我不会改
- <bullet>

## 风险点
- <bullet>

## 计划用到的 skill（5-16 个，已检索）
- <skill-pick/skill-match 选出的路径，如 framework/react/index、style/<项目风格>、simplify ...>
```

4. 等用户回 `干` / `改：<点>` / `算了`。**未确认前不写代码**。

## Step 5 · Build with skills（harness 核心）

确认后主 Agent 直接动手写代码：

- **按需调 skill**：发现任务匹配某 skill 描述就调（如改 React 组件 → `ui-ux-pro-max`；调 Claude API → `claude-api`；写完想精简 → `simplify`）
- **不开 sub-agent 写代码**：dev-lite 的核心简化就在这——主 Agent 直接 Edit/Write/MultiEdit
- **不分批**：一把写完。多文件就 MultiEdit 或多次 Edit，不要拆 BATCH
- **不写 state.json**

写代码过程中如果发现理解卡有偏差 → 立刻停下来告诉用户，不要硬写。

## Step 6 · 可选自检（--review 触发）

只有 `RUN_REVIEW=1` 才跑：

```bash
# 1. 列变更
git diff --stat
git diff

# 2. 按改动目录跑类型检查 / lint（best-effort，工具不存在就跳过）
# - JS/TS: 改动目录里有 package.json → npx tsc --noEmit / npx eslint <files>
# - Python: 有 pyproject.toml → ruff check <files> / mypy <files>

# 3. 主 Agent 自己用 simplify skill 视角扫一眼变更
#    （调 Skill 工具：skill="simplify"）
```

输出 ≤10 行 punch list：
```
## Review 结果
- ✅ <PASS 项>
- ⚠️ <warning 项，但不阻塞>
- ❌ <FAIL 项，建议修>
```

**不自动回修**。把 punch list 给用户，等用户决定。

## Step 7 · 收尾

1. 给用户 ≤ 5 行总结：改了哪些文件 / 引入了什么 skill / 是否跑了 review
2. 更新 `QUILL.md`：
   - 能力清单 `/quill:dev-lite` 状态 ✅
   - 最近活动 append 一行：`[YYMMDD HHMM] /quill:dev-lite <任务一句话> [review=Y/N]`
3. 提示下一步：
   - 想做完整测试 → `/quill:test` / `/quill:test-lite`
   - 需要多批次大型开发 → `/quill:dev`

## 铁律

1. **不开 sub-agent 写代码**（dev-lite 的核心简化）
2. **不分批 / 不 BATCH_ID / 不 state.json**
3. **不强制 PRD**
4. **understand 卡点必须等用户确认**
5. **`--review` 只是质量门，不是回修 loop**
