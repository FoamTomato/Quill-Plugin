# /quill dev / /quill test 编排（4-Agent）

> `/quill dev` 入口 → planner → dev 多批次循环。**默认不链式 test**；要测请跑 `/quill:test` 或用编排器 `/quill:run`。
> `/quill test` 入口 → 只跑 3 tester 并发。编排层先把 artifacts 来源归一（`--batch <ID>` / 自动最新批次 → dev-output.md；无批次 → git diff），**tester 只收 `artifacts` 文件列表，不知来源**。
> `/quill:run` 编排器复用本文件的 Phase 1（planner）+ Phase 2 Step 2.1（dev）+ Step 2.2-2.3（test）作为各 unit 的内循环。
>
> Step 2.2/2.3（测试）受 `RUN_TEST` 控制：`/quill dev` 默认 `RUN_TEST=0`（跳过）；`/quill:run` 的 test stage 或 `/quill dev --then-test` 才置 1。

---

## 主 Agent 五条铁律

1. **主 Agent 不写代码** — 任何源码编辑必须经 dev-coder sub-agent
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

## 软探测输入（缺前置产物不报错退出）

`/quill dev` 启动时**按优先级探测，缺啥降级，绝不 exit**：

```bash
PRD="${QUILL_PRD_DIR}/product-requirements.md"
HLD="${QUILL_PRD_DIR}/high-level-design.md"
REQ=$(ls -1t "${QUILL_PRD_DIR}"/requirement-*.md 2>/dev/null | head -1)
[ -f "$PRD" ] && SRC="$PRD" || SRC="$REQ"   # SRC 可能为空 → 用 task_source 口述
HAS_HLD=0; [ -f "$HLD" ] && HAS_HLD=1
```

- 有 PRD → planner 用 PRD 拆批次；无 PRD 有 `requirement-*.md` → 用它；都无 → 用 `task_source`（口述/Issue）。
- 有 HLD → dev 回写 §九 checklist；**无 HLD → 照常开发，跳过 checklist 回写**，planner 自行从需求/代码推断任务粒度。
- 三者全无且无 task_source → 询问一句话需求，**不退出**。

---

## Phase 0 · 初始化（仅 `/quill dev`）

0.1 生成 BATCH_ID = `<yymmdd>-<short-token>-<seq2>`
    - short-token：从 task_source 提的关键字（snake_case，≤ 10 char）
    - seq：`ls ${QUILL_PRIVATE_DIR}/runs/ 2>/dev/null | grep "^$(date +%y%m%d)-<short>" | wc -l + 1`，补齐 2 位

0.2 `mkdir -p ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/test-reports/{prd,ui,lint}`

0.3 写 `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/main-log.md` 头部（BATCH_ID / 起始时间 / 任务来源）

0.4 给用户确认 1 行：「将启动 planner → dev 多批次开发（不含测试，测试请用 /quill:test 或 /quill:run）。继续? [y/n]」

---

## Phase 1 · 计划（一次性 subagent）

```
Agent(
  subagent_type="dev-planner",
  description="Plan batch",
  prompt="""BATCH_ID=$BATCH_ID
prd_path=$SRC                       # PRD 或 requirement-*.md，可能为空
hld_path=$HLD                       # 可能不存在；不存在则不回写 checklist
task_source=<Issue 号 / 自由文本 / 口述>   # prd_path 为空时的兜底需求来源
"""
)
```

> planner 必须容忍 `prd_path` / `hld_path` 为空或不存在：缺 PRD 用 `task_source` 拆批次；缺 HLD 不产 checklist 引用、按需求粒度切任务。

planner 返回 4 个绝对路径：
- `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-plan.md`
- `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/page-design-guide.md`
- `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/skill-paths.txt`
- `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/authorized-paths.txt` —— **dev 授权范围的单一来源**，dev-coder 与 tester-prd 都认它

主 Agent **不读这 4 个文件的内容**，把路径写入 main-log，进 Phase 2。

---

## Phase 2 · 批量开发循环

```bash
TOTAL_BATCHES=$(grep "^## Batch" ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-plan.md | wc -l)
```

对 N = 1..TOTAL_BATCHES：

### Step 2.1 · 启动 dev（新批必新启）

```
Agent(
  subagent_type="dev-coder",
  description="Dev batch N",
  prompt="""BATCH_ID=$BATCH_ID
batch 编号=N
dev-plan: ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-plan.md (Batch N 段)
design-guide: ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/page-design-guide.md
skills: ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/skill-paths.txt
authorized-paths: ${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/authorized-paths.txt   # 可改文件唯一授权
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

> ⚠️ **仅当 `RUN_TEST=1` 才跑 Step 2.2 + 2.3**。`/quill dev` 默认 `RUN_TEST=0` → dev 收工即进 Step 2.4，**不测**。
> 测试由 `/quill:test`（独立路径）或 `/quill:run` 的 test stage 触发。

**先归一 artifacts（编排层职责，tester 只收文件列表）**：

```bash
# 从本批 dev-output.md 解析 artifacts（tester 不再自己读 dev-output）
DEV_OUTPUT="${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-output.md"
ARTIFACTS=$(awk '/^- artifacts:/{f=1;next} f&&/^  - /{print $2} f&&/^- /&&!/^- artifacts:/{f=0}' "$DEV_OUTPUT" | sort -u)
```

并发启动（**不要顺序调**），每个 tester 传 `artifacts=$ARTIFACTS`：

- test-tester-prd  → `artifacts` + `prd_path` + `hld_path` + `authorized_paths_path=${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/authorized-paths.txt`（授权校验单一来源，与 dev-coder 同源）+ `dev_output_path=$DEV_OUTPUT`（供 checklist 命中校验取本批任务名）→ `${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/test-reports/prd/batch-N.md`
- test-tester-ui   → `artifacts` + 可选 `ui_spec` → `... /ui/batch-N.md`
- test-tester-lint → `artifacts` → `... /lint/batch-N.md`

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

3.1 主 Agent **不**碰 PRD/HLD 同步（已下沉到 dev-coder 收尾职责）

3.2 更新 `QUILL.md`：
- 「能力清单」`/quill dev` `/quill test` 状态改 ✅
- 「产物完成度」勾选「至少 1 个 `.quill/runs/<BATCH_ID>/` 已收工」
- 「最近活动」append 一行

3.3 给用户汇总 + 可选跑 `gh pr create --fill`

---

## `/quill test` 独立路径（编排层归一 artifacts 来源：批次 dev-output / 未提交 git diff）

`/quill test`：以 `RUN_TEST=1` 直接进 Step 2.2（三维并发测试）+ Step 2.3（修正循环）。**Phase 0/1 跳过**。

**编排层先把两种来源归一成 `ARTIFACTS`，再 fan-out**（tester 只收文件列表，不知道也不关心来源）：

```bash
BATCH_ID="${1:-$(ls -1t ${QUILL_PRIVATE_DIR}/runs/ 2>/dev/null | head -1)}"
DEV_OUTPUT="${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/dev-output.md"

if [ -n "$BATCH_ID" ] && [ -f "$DEV_OUTPUT" ]; then
    # batch 来源：从 dev-output.md 解析 artifacts；checklist 校验可比对本批任务名
    ARTIFACTS=$(awk '/^- artifacts:/{f=1;next} f&&/^  - /{print $2} f&&/^- /&&!/^- artifacts:/{f=0}' "$DEV_OUTPUT" | sort -u)
    DEV_OUTPUT_ARG="$DEV_OUTPUT"   # 传给 prd tester 做 checklist 命中校验
    AUTH_ARG="${QUILL_PRIVATE_DIR}/runs/$BATCH_ID/authorized-paths.txt"   # 授权校验单一来源
else
    # git-diff 来源：未提交改动；无 dev-output / authorized-paths → 相应校验降级
    ARTIFACTS=$( { git diff --name-only; git diff --cached --name-only; } 2>/dev/null | sort -u )
    [ -z "$ARTIFACTS" ] && { echo "✅ 无未提交改动，无需测试"; exit 0; }
    DEV_OUTPUT_ARG=""             # 不传 → prd tester 跳过 checklist 命中校验
    AUTH_ARG=""                   # 不传 → prd tester 退回 PRD「涉及目录」段（PRD 在才校验）
    BATCH_ID="gitdiff-$(date +%y%m%d)"   # 占位 ID，仅用于报告落盘
fi
```

三个 tester 一律收 `artifacts=$ARTIFACTS`（prd 额外收 `prd_path`/`hld_path`/可选 `authorized_paths_path=$AUTH_ARG`/可选 `dev_output_path=$DEV_OUTPUT_ARG`，ui 额外收可选 `ui_spec`）。各 tester 内部该跳过的自然降级：prd 在授权来源（authorized-paths 或 PRD 段）缺省时跳过授权校验、PRD/HLD 缺省时跳过一致性、`dev_output_path` 缺省时跳过 checklist 命中；ui 无前端文件直接 PASS。
修正循环：有 dev `DEV_ID` 可 resume 则回修；纯 git-diff（无 dev agent）则只报告 punch list、不自动回修。

---

## test 触发约定

- `/quill dev`：`RUN_TEST=0`，跑完 dev 即停（**不测**）。
- `/quill dev --then-test`：`RUN_TEST=1`，dev 每批后接 Step 2.2/2.3（显式开启链式测试）。
- `/quill test`：独立路径，`RUN_TEST=1`。
- `/quill:run`：编排器按进度决定是否加 test stage（见 `orchestrate.md`）。

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
