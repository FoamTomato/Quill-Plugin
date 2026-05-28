#!/usr/bin/env bash
# skill-pick.sh — 按设计阶段 + 主题关键字，输出 skill 路径清单
#
# 用法：bash skill-pick.sh <kind> <topic...>
#   kind   prd | sketch | ui | hld | plan | dev | lint  (与 skills/ 目录的第一级或语义对齐)
#   topic  关键字（中文/英文，空格分隔）
#
# 输出：一行一个 skill 路径（不含 skills/ 前缀、不含 .md 后缀），后续可喂 skill-get.sh

set -e

LOCAL_DIR="$HOME/.claude/quill-skills"
INDEX_DIR="$LOCAL_DIR/index"
TREE="$INDEX_DIR/tree.json"
KW="$INDEX_DIR/keywords.json"

[ -f "$TREE" ] || { echo "ERROR: $TREE not found, run skill-bootstrap.sh first" >&2; exit 1; }

KIND="${1:?usage: skill-pick.sh <kind> <topic...>}"
shift
TOPICS="$*"

# 1. kind → 候选 skill paths（按 dir 前缀过滤）
declare -a kind_filters
case "$KIND" in
    prd|sketch|ui|hld|plan|dev) kind_filters=("habit/prd-sync" "habit/code-quality" "design-pattern" "framework") ;;
    lint)  kind_filters=("habit/commit" "habit/code-quality" "lang") ;;
    *)     kind_filters=("$KIND") ;;
esac

# 收集 kind 范围内的所有 skill paths
candidates=$(
    for kf in "${kind_filters[@]}"; do
        jq -r --arg p "$kf" '.[] | select(.path | startswith($p)) | .path' "$TREE"
    done | sort -u
)

# 2. 按 topic keyword 匹配（命中加分）
if [ -n "$TOPICS" ]; then
    matched=""
    for t in $TOPICS; do
        t_lc=$(echo "$t" | tr '[:upper:]' '[:lower:]')
        hit=$(jq -r --arg k "$t_lc" '.[$k] // [] | .[]' "$KW" 2>/dev/null || true)
        matched="$matched
$hit"
    done
    # 取交集（candidates 且 matched）
    final=$(echo "$matched" | grep -v '^$' | sort -u | comm -12 - <(echo "$candidates" | sort -u))
    # 兜底：交集为空 → 返回 candidates 的前 5
    [ -z "$final" ] && final=$(echo "$candidates" | head -5)
else
    final=$(echo "$candidates" | head -5)
fi

echo "$final"
