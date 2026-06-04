#!/usr/bin/env bash
# config-write.sh — 首跑：写 .quill-config.json + QUILL.md + 追加 .gitignore
# 用法：bash config-write.sh <prd_dir>

set -e

PRD_DIR="${1:?prd_dir required}"
PROJECT_NAME="$(basename "$(pwd)")"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/个人项目/other/quill-plugin}"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1. 写 .quill-config.json
cat > .quill-config.json <<EOF
{
  "\$schema": "quill-plugin/v2",
  "project_name": "${PROJECT_NAME}",
  "prd_dir": "${PRD_DIR}",
  "private_dir": ".quill",
  "skill_bundle": {
    "source": "https://github.com/FoamTomato/Prompts-MCP/archive/refs/heads/main.tar.gz",
    "fallback": "https://codeload.github.com/FoamTomato/Prompts-MCP/tar.gz/refs/heads/main",
    "local_dir": "~/.claude/quill-skills",
    "version": "",
    "auto_check_update": true
  },
  "created_at": "${NOW}",
  "plugin_version": "0.2.0"
}
EOF

# 2. 写 QUILL.md（从 plugin templates 渲染）
TPL="$PLUGIN_ROOT/templates/QUILL.md.tpl"
if [ -f "$TPL" ]; then
    sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
        -e "s|{{PRD_DIR}}|${PRD_DIR}|g" \
        "$TPL" > QUILL.md
else
    echo "WARN: template $TPL not found, writing minimal QUILL.md" >&2
    echo "# QUILL · ${PROJECT_NAME}" > QUILL.md
fi

# 3. 追加 .gitignore（去重）
touch .gitignore
if ! grep -qE '^\.quill/?$' .gitignore; then
    {
        echo ""
        echo "# Quill plugin private runtime"
        echo ".quill/"
    } >> .gitignore
fi

# 4. 准备 PRD 目录
mkdir -p "$PRD_DIR"

# 5. 准备私有目录
mkdir -p .quill/runs .quill/cache .quill/logs

echo "OK"
echo "project_name=${PROJECT_NAME}"
echo "prd_dir=${PRD_DIR}"
