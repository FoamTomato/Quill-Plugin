# Quill bootstrap 公共段（被各命令引用）

> 不直接以 `/quill:_bootstrap` 调用（命名以 `_` 开头是约定的内部段）。

## 环境保护

```bash
# 0. 不允许在 $HOME 或非 git 目录启动
if [ "$(pwd)" = "$HOME" ]; then
    echo "❌ Quill 不能在 \$HOME ($HOME) 启动 — 会把整个家目录当项目用。"
    echo "   请 cd 到一个具体项目目录后再跑 /quill:* 命令。"
    exit 1
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "⚠️  当前目录不是 git 仓库。Quill 设计为在 git 项目里跑（团队共享 .quill-config.json）。"
    echo "   先 'git init' 或者 cd 到 git 项目，然后重试。"
    exit 1
fi
```

## bootstrap

```bash
eval "$(bash ${CLAUDE_PLUGIN_ROOT}/lib/config-bootstrap.sh)"
```

判断：
- `QUILL_CONFIG_OK=1` 已 export → 静默继续
- `NEEDS_FIRST_RUN` 在输出里 → 走首跑流程

## 首跑流程

1. **AskUserQuestion**：
   - header: `PRD 目录`
   - question: `PRD/HLD 输出目录？（团队共享走 git，私有产物在 .quill/ 自动 gitignore）`
   - options: `docs/prd/<project>/`（推荐）/ `prd/` / 自定义
2. 拿到 PRD_DIR 后：
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/lib/config-write.sh "<PRD_DIR>"
   ```
3. 给用户 1 行确认：`✅ Quill 已就绪，PRD 目录：<PRD_DIR>`

## skill bundle 校验

```bash
test -f "$QUILL_SKILL_DIR/manifest.json" && echo OK || echo MISSING
```

MISSING → `bash ${CLAUDE_PLUGIN_ROOT}/lib/skill-bootstrap.sh`

> **不自动检查更新**。skill bundle 升级由用户手动触发 `/quill:update-skills`。
> 每次 slash 命令都跑 `--check-only` 会污染上下文（多打 1 步 Bash），也会在弱网下卡 5s。
