#!/usr/bin/env bash
# config-bootstrap.sh — 读 .quill-config.json；不存在则提示 main agent 走首跑流程
#
# 行为：
#   1. 如果 .quill-config.json 存在 → 解析并 export QUILL_* 环境变量到 stdout（供 source 用）+ exit 0
#   2. 如果不存在 → stdout 输出 "NEEDS_FIRST_RUN"，并打印推荐的 prd_dir 候选
#   3. main agent 据此决策是否问用户

set -e

# --- Guard rails (block bad working dirs before any side effects) -----------
# Quill writes .quill/, .quill-config.json, QUILL.md, .gitignore append into
# whatever directory it's run from. Two ways that goes very wrong:
#   1) Running in $HOME — pollutes the user's entire home dir as if it were
#      a project (and basename($HOME) often resolves to the username so the
#      "推荐 PRD 目录" becomes things like docs/prd/foam — clearly broken).
#   2) Running outside a git repo — defeats the team-share design: the
#      .quill-config.json that's meant to be committed has no repo to live in.
# These are non-bypassable; stdout below must read as a strict NEEDS_FIRST_RUN-
# equivalent so main agents stop the bootstrap chain rather than skip past it.

if [ "$(pwd)" = "$HOME" ]; then
    cat <<'EOF' >&2
❌ Quill 不能在 $HOME 启动 — 会把整个家目录当项目用。
   请 cd 到一个具体项目目录后再跑 /quill:* 命令。
EOF
    echo "QUILL_REFUSE=home_dir"
    exit 2
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    cat <<'EOF' >&2
⚠️  当前目录不是 git 仓库。Quill 设计为在 git 项目里跑（.quill-config.json 要 push 给团队共享）。
   先 'git init' 或者 cd 到 git 项目，然后重试。
EOF
    echo "QUILL_REFUSE=not_a_git_repo"
    exit 2
fi

CONFIG_FILE="./.quill-config.json"

# --- 项目名推断 -----------------------------------------------------------
# 优先级：CLAUDE.md H1 → package.json name → Cargo.toml name → pyproject.toml name
# → basename(pwd) 兜底。basename 太脆（很多人项目目录就是 src/ / app/ / repo/）。
detect_project_name() {
    local name=""
    if [ -f CLAUDE.md ]; then
        name=$(awk '/^# / { sub(/^# +/, ""); print; exit }' CLAUDE.md 2>/dev/null)
        # 砍掉「· 副标题」/ 「- 描述」尾巴，只留核心名
        name=$(echo "$name" | sed -E 's/[ ]*[·—\-].*$//' | sed -E 's/[[:space:]]+$//')
    fi
    if [ -z "$name" ] && [ -f package.json ]; then
        name=$(jq -r '.name // empty' package.json 2>/dev/null | sed 's|^@[^/]*/||')
    fi
    if [ -z "$name" ] && [ -f Cargo.toml ]; then
        name=$(awk -F'"' '/^name[ ]*=/ { print $2; exit }' Cargo.toml 2>/dev/null)
    fi
    if [ -z "$name" ] && [ -f pyproject.toml ]; then
        name=$(awk -F'"' '/^name[ ]*=/ { print $2; exit }' pyproject.toml 2>/dev/null)
    fi
    [ -z "$name" ] && name="$(basename "$(pwd)")"
    echo "$name"
}
PROJECT_NAME="$(detect_project_name)"

# --- plugin 路径兜底 ------------------------------------------------------
# CLAUDE_PLUGIN_ROOT 由 claude-code 注入；没注入时扫 plugin 缓存取最新版本。
# 不写死 ~/个人项目/other/quill-plugin（开发机以外的环境会直接挂）。
resolve_plugin_root() {
    if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -d "$CLAUDE_PLUGIN_ROOT" ]; then
        echo "$CLAUDE_PLUGIN_ROOT"
        return
    fi
    # 扫 ~/.claude/plugins/cache/*/quill/<version>/ 取版本号最大的
    local found
    found=$(ls -1d "$HOME"/.claude/plugins/cache/*/quill/*/ 2>/dev/null \
              | sort -V | tail -1 | sed 's:/*$::')
    if [ -n "$found" ] && [ -d "$found" ]; then
        echo "$found"
        return
    fi
    # 退化到当前 pwd（开发场景：在 plugin 仓库根目录跑）
    if [ -f ./.claude-plugin/plugin.json ]; then
        pwd
        return
    fi
    echo ""
}
PLUGIN_ROOT="$(resolve_plugin_root)"
if [ -z "$PLUGIN_ROOT" ]; then
    echo "ERROR: 找不到 quill plugin 路径。请通过 'claude plugin install quill' 安装，或在 plugin 仓库根目录运行。" >&2
    echo "QUILL_REFUSE=plugin_not_found"
    exit 2
fi

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
