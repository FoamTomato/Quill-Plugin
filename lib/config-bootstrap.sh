#!/usr/bin/env bash
# config-bootstrap.sh — 读 .quill-config.json；不存在则提示 main agent 走首跑流程
#
# 行为：
#   1. 如果 .quill-config.json 存在 → 解析并 export QUILL_* 环境变量到 stdout（供 source 用）+ exit 0
#   2. 如果不存在 → stdout 输出 "NEEDS_FIRST_RUN"，并打印推荐的 prd_dir 候选
#   3. main agent 据此决策是否问用户

set -e

CONFIG_FILE="./.quill-config.json"
PROJECT_NAME="$(basename "$(pwd)")"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/个人项目/other/quill-plugin}"

if [ -f "$CONFIG_FILE" ]; then
    if ! command -v jq >/dev/null 2>&1; then
        echo "ERROR: jq required. Install via 'brew install jq'." >&2
        exit 1
    fi
    PRD_DIR=$(jq -r '.prd_dir' "$CONFIG_FILE")
    PROJ_NAME=$(jq -r '.project_name // empty' "$CONFIG_FILE")
    PRIV_DIR=$(jq -r '.private_dir // ".quill"' "$CONFIG_FILE")
    SKILL_DIR=$(jq -r '.skill_bundle.local_dir // "~/.claude/quill-skills"' "$CONFIG_FILE")
    SKILL_DIR="${SKILL_DIR/#\~/$HOME}"

    cat <<EOF
export QUILL_CONFIG_OK=1
export QUILL_PROJECT_NAME="$PROJ_NAME"
export QUILL_PRD_DIR="$PRD_DIR"
export QUILL_PRIVATE_DIR="$PRIV_DIR"
export QUILL_SKILL_DIR="$SKILL_DIR"
export QUILL_PLUGIN_ROOT="$PLUGIN_ROOT"
EOF
    exit 0
fi

cat <<EOF
NEEDS_FIRST_RUN
# 推荐 prd_dir 候选（main agent 提示用户选）：
RECOMMEND_1=docs/prd/${PROJECT_NAME}
RECOMMEND_2=prd
RECOMMEND_3=__custom__
PROJECT_NAME=${PROJECT_NAME}
PLUGIN_ROOT=${PLUGIN_ROOT}
EOF
exit 0
