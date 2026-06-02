# Quill 子 agent 分步循环调用规则（主 Agent 必读）

> 所有 `/quill:*` 命令的主 Agent 在调子 agent 时必须按本文档循环驱动，不要"一调到底"。

## 为什么

Sub-agent 在 socket 上单次跑 > 5 分钟容易被网络层切断（你在截图里见过：~6.5 分钟、11 次 tool use 后 socket 掉）。Quill 所有长任务 agent 已改造为**分步执行契约**：单次调用只跑 1 步、写 state.json、return。你（主 Agent）要负责**循环再次调用直到 ALL_DONE**。

## 标准循环（对每个 sub-agent）

```pseudo
phase = "<agent-name>" 或 "<agent-name>-<batch_id>"
state_file = "$QUILL_PRIVATE_DIR/state/$phase.json"

while true:
    # 第一次调用前可以传完整 inputs；后续调用只传 phase + resume=1
    result = Task(subagent_type="quill-<name>", prompt=...)
    
    if "ALL_DONE" in result:
        break
    if "WAITING_FOR_USER_CONFIRMATION" in result:
        # 暂停循环，把 understanding.md 路径列给用户，等用户回 「理解已确认」/「修改：...」
        return_to_user(result)
        await_user_message()
        # 用户确认后继续 loop（下一轮 sub-agent 会把卡点 step 标 done）
        continue
    if "FAILED" in result:
        # 读 state.json 看 notes，决定重试 / 改 plan / 报用户
        handle_failure(result)
        continue
    if "PLAN CREATED" in result or "STEP" in result:
        continue  # 正常推进
    
    # 异常 / 不识别的返回
    log_warn(result)
    break  # 防死循环
```

## 给 sub-agent 的 prompt 写法

**首次调用**：

```
你是 Quill 的 `<agent-name>` 子 agent。
严格按 ${QUILL_SKILL_DIR}/agents/_step-protocol.md 执行。phase = <phase>。

## Inputs
prd_path: ...
... 其他 inputs ...

state.json 不存在 → 按你 agent 文件里的「推荐 plan」初始化，return PLAN CREATED。
```

**后续 resume 调用**（每轮一次）：

```
继续 phase = <phase>。
按 _step-protocol.md：读 state.json → 找 next step → 跑一步 → 标 done → return。
```

后续调用**不要重传 inputs**（state.json 里有）。

## 循环硬上限

- 单 phase 循环 ≤ 25 轮（防死循环）
- 单轮 sub-agent 调用 ≤ 5 分钟（agent 自己应在 3 分钟内 return；超 5 分钟视作 socket 断，按"重新调一次"处理 —— state.json 让它幂等续上）
- 看到连续 3 轮 `FAILED` 同一 step → 停手报用户

## 用户可视反馈

每 3-5 轮循环给用户一行短反馈：

> [phase=prd-writer-full] 进度 4/8 · 当前 §6 API 契约 · 上一步写入 docs/prd/product-requirements.md

让用户感觉到推进，而不是看一堆 sub-agent 调用日志。

## 调试

任何时候用户问"卡哪了"，读 `$QUILL_PRIVATE_DIR/state/$phase.json`：
- `cursor` = 当前步 id
- `plan[cursor-1].status` = 当前步状态
- `notes` = 跨步笔记 / 失败原因
