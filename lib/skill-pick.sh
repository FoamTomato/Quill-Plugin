#!/usr/bin/env bash
# skill-pick.sh — 按设计阶段 + 主题关键字，输出 skill 路径清单
#
# 用法：bash skill-pick.sh [--min N] [--max M] <kind> <topic...>
#   kind   prd | sketch | ui | hld | plan | dev | lint  (与 skills/ 目录的第一级或语义对齐)
#   topic  关键字（中文/英文，空格分隔）
#   --min N  结果不足 N 个时，从候选池补齐到 N（默认不补）
#   --max M  结果超过 M 个时，按相关度截断到 M（默认不截，无 flag 时退回 head 5 兜底）
#
# 输出：一行一个 skill 路径（不含 skills/ 前缀、不含 .md 后缀），后续可喂 skill-get.sh

set -e

LOCAL_DIR="$HOME/.claude/quill-skills"
INDEX_DIR="$LOCAL_DIR/index"
TREE="$INDEX_DIR/tree.json"
KW="$INDEX_DIR/keywords.json"

[ -f "$TREE" ] || { echo "ERROR: $TREE not found, run skill-bootstrap.sh first" >&2; exit 1; }

# --- 解析 flag（--min / --max / --ensure-style；先从 $@ 剥离，剩下的才是 kind + topics）---
MIN=""
MAX=""
ENSURE_STYLE=0   # dev/plan 开发时置 1：强制把「开发风格类 skill」钉到结果最前、不被截断
positional=()
while [ $# -gt 0 ]; do
    case "$1" in
        --min) MIN="$2"; shift 2 ;;
        --max) MAX="$2"; shift 2 ;;
        --min=*) MIN="${1#--min=}"; shift ;;
        --max=*) MAX="${1#--max=}"; shift ;;
        --ensure-style) ENSURE_STYLE=1; shift ;;
        *) positional+=("$1"); shift ;;
    esac
done
set -- "${positional[@]}"

KIND="${1:?usage: skill-pick.sh [--min N] [--max M] <kind> <topic...>}"
shift
TOPICS="$*"

# 1. kind → 候选 skill paths（按 dir 前缀过滤）
declare -a kind_filters
case "$KIND" in
    ui|style) kind_filters=("style" "framework" "habit/baseline" "habit/code-quality") ;;
    prd|sketch|hld|plan|dev) kind_filters=("habit/baseline" "habit/prd-sync" "habit/code-quality" "design-pattern" "framework" "style") ;;
    lint)  kind_filters=("habit/commit" "habit/code-quality" "lang") ;;
    *)     kind_filters=("$KIND") ;;
esac

# 收集 kind 范围内的所有 skill paths
# 按 kind_filters 的声明顺序排列（靠前的类别优先），dedup 保留首次出现。
# 不能用 sort -u —— 否则字母序会把高优先类别（如 prd/hld 档的 habit/prd-sync）
# 挤到 design-pattern/* 后面，无 topic 的 head -5 兜底就拿不到真正相关的 skill。
candidates=$(
    for kf in "${kind_filters[@]}"; do
        jq -r --arg p "$kf" '.[] | select(.path | startswith($p)) | .path' "$TREE" | sort
    done | awk '!seen[$0]++'
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

# 2.5 --ensure-style：把「必读规约类 skill」钉到结果最前（dev/plan 开发必检）------
# 命中四类，钉到最前 → 后面的 head -max 截断不会丢：
#   habit/baseline/      语言无关基础写法宪法，无条件必读
#   habit/code-quality/  通用代码质量/命名风格
#   style/ 与 */style/    顶级项目风格（/quill:ui 产物）+ 语言代码风格
#   */*-style/           语言代码风格的别名目录（如 coding-style/）
if [ "$ENSURE_STYLE" = "1" ]; then
    style_paths=$(
        jq -r '.[] | .path
            | select(
                startswith("style/")
                or test("/style/")
                or test("/[a-z-]*-style/")
                or startswith("habit/baseline")
                or startswith("habit/code-quality")
              )' "$TREE" 2>/dev/null | sort
    )
    if [ -n "$style_paths" ]; then
        # 风格类在前、原 final 在后，dedup 保留首次（即风格优先）
        final=$(printf '%s\n%s\n' "$style_paths" "$final" | grep -v '^$' | awk '!seen[$0]++')
    fi
fi

# 3. --min / --max 夹逼 -------------------------------------------------------
#    final = topic 命中（最相关，优先保留）；pad 池 = candidates 里尚未入选的
clamp() {
    local list="$1" min="$2" max="$3" pool="$4"
    list=$(echo "$list" | grep -v '^$')
    # 补齐到 min：从 pool 里追加未入选项
    if [ -n "$min" ]; then
        local have; have=$(echo "$list" | grep -c '.' || true)
        if [ "$have" -lt "$min" ]; then
            local extra
            extra=$(echo "$pool" | grep -v '^$' | sort -u | comm -23 - <(echo "$list" | sort -u))
            list=$(printf '%s\n%s\n' "$list" "$extra" | grep -v '^$' | awk '!seen[$0]++')
        fi
    fi
    # 截断到 max（topic 命中在前，故 head 即"最相关优先"）
    if [ -n "$max" ]; then
        list=$(echo "$list" | grep -v '^$' | head -n "$max")
    fi
    echo "$list" | grep -v '^$'
}

if [ -n "$MIN" ] || [ -n "$MAX" ]; then
    final=$(clamp "$final" "$MIN" "$MAX" "$candidates")
fi

echo "$final"
