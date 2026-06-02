---
name: _step-protocol
description: Quill 子 agent 通用分步执行契约。所有长任务 agent（dev-coder / dev-planner / test-tester-*）必须遵守。
---

# Quill 分步执行契约（共享规范）

## 为什么存在

Sub-agent 在 socket 上单次跑超过 ~5 分钟 / 12 次 tool use 容易被切。**真长任务**（dev-coder 一批多文件 / tester 多目录）需要拆成小步，断了能从 state.json 续。

## ⚠️ 何时该用本契约

- ✅ **该用**：dev-coder / dev-planner / test-tester-* —— 真多任务
- ❌ **不该用**：prd-writer-full / hld-writer-full / hld-writer-lite / prd-writer-lite / flow-writer / ui-style-author —— 这些任务单次 3 分钟内能完成，分步只是徒增 8 倍 overhead

简单 agent 默认单次调用一把出；只有当 prompt 里显式带 `mode=stepwise` 时才回退到本契约。详见各 agent 文件顶部的「执行模式」段。

## 状态文件位置

```
${QUILL_PRIVATE_DIR}/state/<phase>.json
```

`<phase>` 取值：`planner-<BATCH_ID>` / `dev-batch-<N>` / `tester-prd-batch-<N>` / `tester-ui-batch-<N>` / `tester-lint-batch-<N>`。

## state.json 格式

```json
{
  "phase": "prd-writer-full",
  "version": 1,
  "created_at": "2026-05-29T12:00:00Z",
  "updated_at": "2026-05-29T12:03:00Z",
  "plan": [
    {"id": 1, "title": "识别模式 + 读 outline/source", "status": "done"},
    {"id": 2, "title": "写 §一-三 背景/预览/明细", "status": "done"},
    {"id": 3, "title": "写 §四 API 契约",          "status": "in_progress"},
    {"id": 4, "title": "写 §五 数据库 schema",     "status": "pending"},
    {"id": 5, "title": "写 §六 涉及目录",          "status": "pending"},
    {"id": 6, "title": "写 §七-九 功能/流程/验收", "status": "pending"},
    {"id": 7, "title": "写 §十 Change Log + 自检", "status": "pending"}
  ],
  "cursor": 3,
  "inputs": { "prd_path": "...", "source": "...", "outline": "..." },
  "notes": "可选：跨步骤需要传的小笔记，≤500 字"
}
```

`status` ∈ {`pending`, `in_progress`, `done`, `failed`}。`cursor` 是下一个要跑的 step id。

## 每次调用的标准流程

```
1. Read ${QUILL_PRIVATE_DIR}/state/<phase>.json
   - 不存在 → 首次调用：先执行 §"规划阶段"，写 state.json，return
   - 存在 → 进入步骤执行

2. 找到第一个 status != "done" 的 step
   - 全部 done → 写 "ALL_DONE" 到 stdout，return

3. 把该 step 设为 in_progress、更新 updated_at、Write state.json
   （先标记再干活，防止断了不知道刚跑到哪）

4. 执行该 step 的实际工作（参考各 agent 的步骤定义）
   ⚠️ 单步预算硬上限：
     - tool use ≤ 6 次
     - 时间 ≤ 3 分钟
     - 写入文件数 ≤ 3 个
   如果发现一步装不下 → 中止，把当前 step 拆成 2 个，写回 plan，return

5. 把该 step 设为 done、cursor 推进、Write state.json

6. Return 一段 ≤200 字的简报：
   ```
   STEP <id>/<total> DONE: <title>
   artifacts: <写了哪些文件>
   next: STEP <id+1> <title>  (或 ALL_DONE)
   ```
   ❌ 不要把刚写的文件内容回贴到响应里
```

## 规划阶段（首次调用，state.json 不存在）

1. Read 所有输入（PRD/outline/source/dev-plan 等，按 agent 而定）
2. 把工作拆成 5-10 个小步，每步必须满足"单步预算"
3. Write state.json，所有 step 都是 `pending`，cursor=1
4. Return：
   ```
   PLAN CREATED (N steps):
   - 1. <title>
   - 2. <title>
   ...
   next: STEP 1 <title>
   ```
5. **不要在这一轮顺便跑 step 1**。规划本身就是一次调用。

## 父 agent 怎么驱动

父 agent（dev-coder 或主 command）伪代码：

```
while true:
    result = invoke_subagent(phase=X, inputs=...)
    if "ALL_DONE" in result: break
    if "PLAN CREATED" in result: continue   # 立刻进下一轮跑 step 1
    if "STEP" in result and "DONE" in result: continue
    if "FAILED" in result: handle / abort
```

父 agent 每轮再次调用时**不需要重复传完整 inputs** —— inputs 已经在 state.json 里。只传 `phase=X`、`resume=1` 即可。

## 断点恢复语义

- state.json 在则**永远以它为准**，不重读 inputs 决定 cursor
- 如果某个 step 卡在 `in_progress` 状态超过一个调用周期（父 agent 应记录上次调用时间），说明上次断在干这步中间 → 直接重跑这步（覆盖式，保证幂等）
- step 执行必须**幂等**：写文件用 Write 覆盖，不要 append 累积写（dev-output.md 等 append 文件除外，那种要先读后判重）

## 失败处理

- 工具调用失败 / 信息缺失 → 把 step status 改 `failed`，notes 记原因，return `FAILED: step <id> reason=<...>`
- 父 agent 决定是重试（再调一次）还是改 plan（注入修正后调一次）

## 单步预算违例的兜底

如果在一步里发现工作量被低估了，**立刻停手**，把当前 step 拆分：

```
原:  {"id": 3, "title": "写 §3-5 需求设计预览/明细", "status": "in_progress"}
拆后:
{"id": 3,   "title": "写 §3-5 需求设计预览/明细", "status": "done"}   // 已写完的部分
{"id": 3.1, "title": "续写 §5 剩余 M3-M5",        "status": "pending"}
```

或者用插入新 id 的方式（cursor 跳到新 id）。重点：**不要硬扛把一步跑超 3 分钟**。

## 调试

任何时候用户手动看 `${QUILL_PRIVATE_DIR}/state/<phase>.json` 都能知道：跑到第几步 / 哪步在跑 / 哪步挂了 / plan 长什么样。这也是用户介入修复的入口。
