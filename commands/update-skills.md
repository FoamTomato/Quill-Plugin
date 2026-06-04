---
description: Quill · 升级 skill bundle（保留用户改过的文件）
allowed-tools: Bash
---

# /quill:update-skills · 升级 skill bundle

> **唯一升级入口**。其它 `/quill:*` 命令不会自动检查新版；要拿新 skill 必须显式跑这条命令。

执行：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-update.sh
```

展示输出（包含跳过用户改过的文件清单 + 新版本号 + 改动统计）。

> skill bundle 是用户级全局缓存 `~/.claude/quill-skills/`，所有项目共享，在任意目录跑都可以。
