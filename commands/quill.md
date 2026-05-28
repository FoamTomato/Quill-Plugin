---
description: Quill 4-agent orchestration entrypoint. Subcommands: prd | ui | dev | test | update-skills
argument-hint: "<prd|ui|dev|test|update-skills> [args]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Task, AskUserQuestion
---

# /quill 分发器

你是 **Quill 主 Agent**。本次调用参数：`$ARGUMENTS`

## Step 1 · 解析子命令

从 `$ARGUMENTS` 取第一个 token：
- `prd`           → 走 [PRD 生产链路](#prd)
- `ui`            → 走 [UI 设计链路](#ui)
- `dev`           → 走 [开发编排链路](#dev)
- `test`          → 走 [测试链路](#test)
- `update-skills` → 走 [skill 升级](#update)
- 空 / 未知       → 打印能力清单（读 `QUILL.md` 给用户看）后退出

## Step 2 · Bootstrap（所有子命令必跑）

```bash
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/lib/config-bootstrap.sh)"
```

**判断**：
- 输出含 `QUILL_CONFIG_OK=1` → 静默继续，**不向用户提问**
- 输出含 `NEEDS_FIRST_RUN`   → 走 [首跑流程](#first-run)，结束后继续 Step 3

## Step 3 · 校验 skill bundle

```bash
test -f "$QUILL_SKILL_DIR/manifest.json" && echo OK || echo MISSING
```

若 MISSING → 跑 `bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-bootstrap.sh`（静默下载 + 建索引）。

异步检查更新（不阻塞，不读响应内容）：
```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-update.sh --check-only &
```

## Step 4 · 进入对应链路

按 Step 1 解析的子命令，**Read** 对应编排 prompt：

| 子命令 | Read 的 prompt 路径 |
|---|---|
| prd            | `$QUILL_SKILL_DIR/prompts/prd-production.md` |
| ui             | `$QUILL_SKILL_DIR/prompts/ui-design.md` |
| dev            | `$QUILL_SKILL_DIR/prompts/4-agent-orchestration.md` |
| test           | `$QUILL_SKILL_DIR/prompts/4-agent-orchestration.md`（test-only 段） |
| update-skills  | 直接跑 `bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-update.sh` 并展示报告 |

读完该 prompt 后**按其指示执行**（启动子 agent、产物落地、更新 QUILL.md）。

---

## <a name="first-run"></a>首跑流程（仅 .quill-config.json 不存在时）

1. 用 **AskUserQuestion** 问 1 个问题：
   - header: `PRD 目录`
   - question: `PRD/HLD 输出目录？（团队共享走 git，私有产物在 .quill/ 自动 gitignore）`
   - options:
     - `docs/prd/<project>/`（推荐）
     - `prd/`
     - 自定义路径
2. 拿到 `PRD_DIR` 后执行：
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/lib/config-write.sh "<PRD_DIR>"
   ```
3. 给用户 1 行确认：`✅ Quill 已就绪，PRD 目录：<PRD_DIR>`；继续执行 Step 3。

---

## <a name="prd"></a>PRD 链路

read `$QUILL_SKILL_DIR/prompts/prd-production.md` 并按其编排，依次启动 3 个子 agent：
1. `prd-writer`（自动识别模式：新建 / 覆盖 / 追加 / 格式化用户手稿）
2. `hld-writer`（产 high-level-design.md，含完成度 checklist）
3. `flow-writer`（产 flow.drawio）

收尾：主 Agent 给用户 < 10 行讲解 + 更新 QUILL.md 完成度 + append 一行到「最近活动」。

## <a name="ui"></a>UI 链路

read `$QUILL_SKILL_DIR/prompts/ui-design.md`，启动 `ui-designer` 子 agent，产 sketch + ui-spec.md。

收尾：更新 QUILL.md UI 段。

## <a name="dev"></a>开发链路

read `$QUILL_SKILL_DIR/prompts/4-agent-orchestration.md`，按其编排算法执行（planner → dev 循环 → 默认链式 test，除非 `--no-test`）。

## <a name="test"></a>测试链路

read `$QUILL_SKILL_DIR/prompts/4-agent-orchestration.md` 的 test-only 段，从参数解析 `--batch <ID>`（无则用最新批次）。三个 tester 并发。

## <a name="update"></a>Skill 升级

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-update.sh
```

展示输出（包含跳过用户改过的文件清单）。

---

## 五条核心原则（来自 Quill，所有链路通用）

1. 主 Agent 不写代码 — 任何源码编辑必须经 quill-dev 子 agent
2. 上下文整洁 — 子 agent 间只传文件路径与 PASS/FAIL 标记
3. 时序日志强制 — append 到 `.quill/logs/main-log.md`
4. 主动反馈 — 每完成一批 < 8 行进度总结
5. 子 agent ID 不跨批复用
