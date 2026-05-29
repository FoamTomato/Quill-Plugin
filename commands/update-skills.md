---
description: Quill · 升级 skill bundle（保留用户改过的文件）
allowed-tools: Bash
---

# /quill:update-skills · 升级 skill bundle

执行：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-update.sh
```

展示输出（包含跳过用户改过的文件清单 + 新版本号 + 改动统计）。

> 不需要在具体项目里跑 — skill bundle 是用户级全局缓存 `~/.claude/quill-skills/`，所有项目共享。
