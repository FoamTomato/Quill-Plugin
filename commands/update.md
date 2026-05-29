---
description: Quill · 一键升级（plugin 仓库 + skill bundle + agent 软链）
argument-hint: "[--plugin-only | --skills-only | --local <dir>]"
allowed-tools: Bash
---

# /quill:update · 一键升级

> 把 Quill 升到最新版，**省去卸载重装**。包含三块：
> 1. plugin 仓库（commands/ + agent prompt metadata）—— 跑 `claude plugin marketplace update quill` + `plugin update quill`
> 2. skill bundle（`~/.claude/quill-skills/skills/` + agents + prompts）—— 复用 `skill-update.sh`，保留你改过的文件
> 3. `~/.claude/agents/quill-*.md` 软链 —— 清掉失效链 + 给新增 agent 建链

执行：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/update.sh $ARGUMENTS
```

展示输出（含每一阶段进度 + skill bundle 的 updated/added/skipped 统计）。

## 常见用法

| 场景 | 命令 |
|---|---|
| 拿最新 plugin + skill | `/quill:update` |
| 只更 skill 库（不重启 Claude） | `/quill:update --skills-only` |
| 只更 plugin 仓库 | `/quill:update --plugin-only` |
| 本地源调试 | `/quill:update --local /path/to/repo` |

## 注意

- **plugin 部分的改动要重启 Claude Code 才生效**（commands、agent metadata 由 Claude Code 启动时加载）。skill bundle 改动不需要重启。
- 你手改过的 skill / agent 文件**不会被覆盖**（manifest 用 sha256 防丢）。被跳过的清单在更新报告里。
- 第一次安装请用 `claude plugin marketplace add ... && claude plugin install quill@quill`，不要用 `/quill:update`。
