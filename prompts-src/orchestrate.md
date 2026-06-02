# /quill:run 编排器（动态路由 + 3-并发上限）

> 入口：`/quill:run`（opt-in）。主 Agent 只**指挥** planner / dev / test 子 agent，**自己不写代码 / 不写文档 / 不画图**。
> 先**自动判断当前需求进度**（靠 `quill-detect.sh`），再**动态决定调哪些子 agent、按什么顺序、能否并发** —— 不是固定 planner→dev→test 流水线。

---

## 编排器铁律

1. **不写代码 / 不写文档 / 不画图** —— 一切经子 agent（planner / dev / tester）。
2. **只读 `quill-detect.sh` 的 KEY=VALUE + tester 报告 `head -1`**，绝不读任何全文。
3. **任一 stage 同时最多 3 个子 agent**（硬上限，见「并发上限协议」）。
4. **不固定流程** —— 探测结果决定调哪些 agent。
5. 缺前置产物 → **建议用户先跑对应 `/quill:*`**，不自己补。

---

## 可调度的三种身份

- **planner** = `dev-planner`（一个独立需求切片一个）
- **dev** = `dev-coder`（一个 batch 一个；DEV_ID 同批唯一、不跨批复用）
- **test-unit** = `test-tester-prd` + `test-tester-ui` + `test-tester-lint`（**一个 batch 的三件套算 1 个 unit**）

---

## Step A · 读进度

```bash
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/lib/quill-detect.sh)"   # 注入 HAS_PRD/HAS_HLD/... 变量
bash ${CLAUDE_PLUGIN_ROOT}/lib/quill-detect.sh             # 再打印给用户看
```

只看这些 KEY=VALUE 做路由判断。

## Step B · 路由决策表（R0-R9）→ 拼 stage DAG

自上而下匹配（每分支首个命中即采用；多分支可叠成 DAG）：

| # | 条件（来自 quill-detect） | 路由动作 | 理由 |
|---|---|---|---|
| R0 | `HAS_PRD=0` | **停** → 提示「先 `/quill:prd` 或 `/quill:prd-lite` 再回 `/quill:run`」 | planner 需要 PRD 才能切 |
| R1 | `HAS_PRD=1 HAS_HLD=0` | **停** → 建议 `/quill:hld`（或 `/quill:hld-lite`） | dev 需要 HLD §九 checklist + §八 接口 |
| R2 | `HAS_PRD=1 HAS_HLD=1 RUNS_TOTAL=0` | **planner → dev → test**（全新流水线） | 啥都没建 |
| R3 | 最新批 `LATEST_DEV_DONE=0`（planner 跑过、dev 未完） | **dev**（resume 最新批，走 Phase 2）→ **test** | 别重 plan，先把这批做完 |
| R4 | `LATEST_DEV_DONE=1 LATEST_TEST_PASS=0` | **只 test**（独立路径，`LATEST_BATCH`） | 代码在、没测/没过 |
| R5 | `LATEST_DEV_DONE=1 LATEST_TEST_PASS=1 GIT_DIRTY>0` | **test 限 git-diff**（不重 plan） | 绿批之后有手改 |
| R6 | `LATEST_TEST_PASS=1 GIT_DIRTY=0` 且有新 task_source | **planner → dev → test**（**新 BATCH_ID**） | 上批已收，这是下一个需求 |
| R7 | `HLD_UNCHECKED>0` 且 `LATEST_TEST_PASS=1` | **planner 切未勾项 → dev → test** | HLD 还有没建的项 |
| R8（修饰） | task_source 含 **≥2 个独立模块**（planner 出 >1 batch / 用户输入可拆） | **多 planner / 多 dev 并行**（见并发协议） | 「需求、任务、测试可并发则同时跑更快」 |
| R9（修饰） | `HAS_STYLE_SKILL=0` 且任务涉及前端 | **建议**先 `/quill:ui`（风格 skill 工厂），**不阻塞** | 让 dev 检索复用风格 skill |

把命中分支拼成 **stage DAG**，例：
- R2 → `[plan] → [dev] → [test]`（3 个顺序 stage，stage 内按并发协议 fan-out）
- R8 叠 R2 → `[plan×k] → [dev×k] → [test×k]`（每 stage fan-out，封顶 3）
- R4 → `[test]`（单 stage）

## Step C · 出计划等确认

用 AskUserQuestion 给用户**一次性确认**本次 DAG：列出跑哪些 stage、每 stage 开几个子 agent、哪些并发。
`--dry-run` → 只打印 DAG，**停手不执行**。

## Step D · 分 stage 执行（并发上限协议）

```
MAX_PARALLEL = min(3, --max-parallel 参数若给)   # 硬天花板 3，永不超
for each stage S in DAG:                          # stage 之间顺序（dev 等 plan；test 等该 unit 的 dev）
    units = 该 stage 的独立 work unit（planner 的 batch 数 / R8 切片）
    queue = units
    while queue 非空:
        wave = 从 queue 取 ≤ MAX_PARALLEL 个 unit          # ≤3
        同一回复内并发发 wave 的 Task 调用
        每个 Task 都是 subagent-loop.md 的一步（单步契约）
        round-robin 推进 wave 里每个 unit 的 loop，直到各自 ALL_DONE
        （或 WAITING_FOR_USER_CONFIRMATION）
        # 某 unit 返回 ALL_DONE 后才从 queue 取下一个补位，始终 ≤3 在飞
    # 本 stage queue 排空后才进下一 stage
```

**为什么恒 ≤3 并发**：
1. wave 一次最多取 3；第 4 个 unit 只在某 in-flight unit `ALL_DONE` 后才发。
2. **test 三件套是 unit 内部 fan-out，不占编排器的 3 槽**：一个「batch N 的 test unit」= 1 槽，其内部 3 个 tester 的并发由 `4-agent-orchestration.md` Step 2.2 管。想并行测 2 个 batch = 2 槽（≤3），各自再 fan-out 自己的 3 tester。**编排器层永远只数 unit，不数 tester**（最易错点）。
3. `subagent-loop.md` 已是每步一调；编排器只是 round-robin ≤3 个 phase 的 loop，socket 超时保护天然继承。

**并行 unit 的 state 隔离**：每个 unit 用不同 `phase`（→ 不同 `$QUILL_PRIVATE_DIR/state/<phase>.json`），互不踩 cursor：
- planner：`planner-<BATCH_ID_slice_k>`
- dev：`dev-batch-<N>`
- tester：`tester-{prd,ui,lint}-batch-<N>`

## Step E · 委托内循环 + 卡点传播

每个 unit 的内循环**直接走** `4-agent-orchestration.md`，不重复实现：
- planner unit → 该文件 **Phase 1**
- dev unit → **Phase 2 Step 2.1**
- test unit → **Phase 2 Step 2.2-2.3**（或「/quill test 独立路径」for R4/R5）

dev 的 understanding 卡点（`WAITING_FOR_USER_CONFIRMATION`）原样上抛：编排器**暂停该 unit 的 loop、列 understanding.md 路径给用户**，但**可继续推进其余 ≤2 个并行 unit**，不阻塞。

## Step F · 收尾

更新 `QUILL.md`（`/quill:run` ✅、最近活动 append、产物完成度勾选），给 ≤8 行总结 + 下一步建议。

## 时序日志

沿用 `.quill/runs/<BATCH>/main-log.md` 格式；多 unit 并行时每行加 `unit=<phase>` 前缀，便于用户看 ≤3 个并行 unit 的推进。
