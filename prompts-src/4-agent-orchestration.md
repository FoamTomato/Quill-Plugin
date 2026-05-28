# /quill dev / /quill test 编排（4-Agent）

> `/quill dev` 入口 → 走完整 4-Agent 循环（planner → dev → 3 tester 并发 → FAIL 回修，默认链式 test）
> `/quill test` 入口 → 只跑 3 tester 并发（必须指定 `--batch <ID>` 或自动用最新批次）

---

## 主 Agent 五条铁律

1. **主 Agent 不写代码** — 任何源码编辑必须经 quill-dev sub-agent
2. **上下文整洁** — sub-agent 之间只传文件路径与 PASS/FAIL 标记
3. **时序日志强制** — append 到 `${QUILL_PRIVATE_DIR}/runs/<BATCH_ID>/main-log.md`，格式 `[yymmdd hhmm] <event>`
4. **主动反馈** — 每完成一批 < 8 行进度总结
5. **DEV_ID 唯一性** — 同一批次 dev 必须 resume 同一 agentId；新批必须新启

## 绝对禁止清单

- ❌ 主 Agent Read PRD 全文 / 源码 / 测试报告全文
- ❌ 主 Agent Edit/Write/MultiEdit
- ❌ 跨批次复用同一 dev agentId
- ❌ tester 报告未 `head -1` 拿 `### 判定：` 就做决策

---

## 前置校验

`/quill dev` 启动时：

```bash
[ -f "${QUILL_PRD_DIR}/product-requirements.md" ] || { echo "❌ 缺 PRD，请先 /quill prd"; exit 1; }
[ -f "${QUILL_PRD_DIR}/high-level-design.md" ]     || { echo "❌ 缺 HLD，请先 /quill prd"; exit 1; }
```

---

## Phase 0 · 初始化（仅 `/quill dev`）

0.1 生成 BATCH_ID = `<yymmdd>-<short-token>-<seq2>`
    - short-token：从 task_source 提的关键字（snake_case，≤ 10 char）
    - seq：`ls ${QUILL_PRIVATE_DIR}/runs/ 2>/dev/null | grep "^$(date +%y%m%d)-<short>" | wc -l + 1`，补齐 2 位

0.2 `mkdir -p ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/test-reports/{prd,ui,lint}`

0.3 写 `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/main-log.md` 头部（BATCH_ID / 起始时间 / 任务来源）

0.4 给用户确认 1 行：「将启动 4-Agent 编排（planner → dev → 3 tester），预计 5-15 次 sub 调用。继续? [y/n]」

---

## Phase 1 · 计划（一次性 subagent）

```
Agent(
  subagent_type="quill-planner",
  description="Plan batch",
  prompt="""BATCH_ID=$BATCH_ID
prd_path=$QUILL_PRD_DIR/product-requirements.md
hld_path=$QUILL_PRD_DIR/high-level-design.md
ui_spec=$QUILL_PRD_DIR/ui-spec.md
task_source=<Issue 号 / 自由文本>
"""
)
```

planner 返回 3 个绝对路径：
- `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-plan.md`
- `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/page-design-guide.md`
- `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/skill-paths.txt`

主 Agent **不读这 3 个文件的内容**，把路径写入 main-log，进 Phase 2。

---

## Phase 2 · 批量开发循环

```bash
TOTAL_BATCHES=$(grep "^## Batch" ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-plan.md | wc -l)
```

对 N = 1..TOTAL_BATCHES：

### Step 2.1 · 启动 dev（新批必新启）

```
Agent(
  subagent_type="quill-dev",
  description="Dev batch N",
  prompt="""BATCH_ID=$BATCH_ID
batch 编号=N
dev-plan: ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-plan.md (Batch N 段)
design-guide: ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/page-design-guide.md
skills: ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/skill-paths.txt
prd_path: $QUILL_PRD_DIR/product-requirements.md
hld_path: $QUILL_PRD_DIR/high-level-design.md
完成后 append artifacts 到 ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-output.md
"""
)
```

dev 收工后 SubagentStop hook 自动写 `agent-ids.json.dev = DEV_ID`。

```bash
DEV_ID=$(jq -r '.dev' ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/agent-ids.json)
```

Fallback（hook 没拿到 agentId）：

```bash
find ~/.claude/projects/ -name "agent-*.meta.json" -print0 2>/dev/null \
  | xargs -0 stat -f '%m %N' 2>/dev/null \
  | sort -rn | head -1 | cut -d' ' -f2- \
  | xargs -I {} basename {} | sed -E 's/^agent-(.+)\.meta\.json$/\1/'
```

### Step 2.2 · 三维并发测试（同一回复内三个 Agent call）

并发启动（**不要顺序调**）：

- quill-tester-prd  → `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/test-reports/prd/batch-N.md`
- quill-tester-ui   → `... /ui/batch-N.md`
- quill-tester-lint → `... /lint/batch-N.md`

主 Agent **只读首行**：

```bash
for d in prd ui lint; do
  head -1 ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/test-reports/$d/batch-N.md
done
```

期望 `### 判定：PASS` 或 `### 判定：FAIL`。**绝不读报告全文**。

### Step 2.3 · 修正循环（≤ 3 轮）

```
round = 0
while round < 3:
    fails = [d for d in (prd,ui,lint) if "FAIL" in head -1 报告]
    if not fails:
        log "batch-N PASS @ round=$round"
        break

    fail_paths = "; ".join(f"${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/test-reports/{d}/batch-N.md" for d in fails)
    SendMessage(
        to=DEV_ID,
        message=f"batch-N round={round+1}：以下维度 FAIL，按报告逐条修复：{fail_paths}\n修复后 append '## round-{round+1} fixed: ...' 到 dev-output.md"
    )
    # 等 dev 收工 → 并发 resume 那些 FAIL 的 tester
    parallel for d in fails:
        SendMessage(to=TESTER_IDS[d], message=f"重测 batch-N round-{round+1}")
    round += 1

if round == 3 and fails:
    log "batch-N 留待人工: $fails"
    ask_user("3 轮 FAIL ($fails)，暂停 / 跳过本批 / 终止？")
    # 推荐：暂停（理由：跳过会让后续 batch 在 broken base 上叠 bug）
```

### Step 2.4 · 进下一批前

```bash
jq --arg n "$N" --arg id "$DEV_ID" '.dev_history[$n] = $id | .dev = null' \
  ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/agent-ids.json > /tmp/ids.tmp && mv /tmp/ids.tmp ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/agent-ids.json
```

TESTER_*_ID 保留复用（同会话 resume 比新启省 token）。

---

## Phase 3 · 收工

3.1 主 Agent **不**碰 PRD/HLD 同步（已下沉到 quill-dev 收尾职责）

3.2 更新 `QUILL.md`：
- 「能力清单」`/quill dev` `/quill test` 状态改 ✅
- 「产物完成度」勾选「至少 1 个 `.quill/runs/<BATCH_ID>/` 已收工」
- 「最近活动」append 一行

3.3 给用户汇总 + 可选跑 `gh pr create --fill`

---

## `/quill test` 独立路径

`/quill test --batch <ID>`（不传 ID 则用最新批次）：

```bash
BATCH_ID="${1:-$(ls -1t ${QUILL_PRIVATE_DIR}/runs/ | head -1)}"
[ -d "${QUILL_PRIVATE_DIR}/runs/$BATCH_ID" ] || { echo "❌ 批次 $BATCH_ID 不存在"; exit 1; }
[ -f "${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-output.md" ] || { echo "❌ 该批次未跑过 dev"; exit 1; }
```

直接进 Step 2.2（三维并发测试） + Step 2.3（修正循环）。**Phase 0/1 跳过**。

---

## `--no-test` 选项

`/quill dev --no-test`：跑完 Phase 2 dev 后不自动链式 test，停在 Step 2.1 收工。用户后续可手动 `/quill test --batch <ID>`。

---

## 时序日志格式

```
[260528 1900] BATCH_ID=260528-dashboard-01 init
[260528 1901] planner started
[260528 1905] planner done, 2 batches/8 tasks
[260528 1906] batch-1 dev started, id=a1b2c3
[260528 1925] batch-1 dev done, awaiting understanding confirm
[260528 1930] user confirmed, dev coding
[260528 1955] batch-1 dev finished, 4 artifacts
[260528 1956] batch-1 testers concurrent: prd/ui/lint
[260528 2010] batch-1 prd=PASS ui=PASS lint=FAIL
[260528 2011] batch-1 round-1 SendMessage dev (lint FAIL)
...
```
