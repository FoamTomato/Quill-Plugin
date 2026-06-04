#!/usr/bin/env bash
# skill-match.sh — 按文件路径 glob + 关键字反查 skill
#
# 用法：bash skill-match.sh [--min N] [--max M] "<file_globs>" "<keywords>"
#   file_globs  逗号分隔，如 "src/**/*.tsx,components/**/*.tsx"
#   keywords    空格分隔
#   --min N     结果不足 N 个时，放宽（lang 推断 / 全 tree 兜底）补齐到 N
#   --max M     结果超过 M 个时，截断到 M
#
# 输出：一行一个 skill 路径。无 --min/--max 时行为与旧版一致（不设上限）。

set -e

LOCAL_DIR="$HOME/.claude/quill-skills"
INDEX_DIR="$LOCAL_DIR/index"
PATHS="$INDEX_DIR/paths.json"
KW="$INDEX_DIR/keywords.json"
TREE="$INDEX_DIR/tree.json"

# --- 解析 --min / --max（先剥离，剩下才是 positional）-----------------------
MIN=""
MAX=""
positional=()
while [ $# -gt 0 ]; do
    case "$1" in
        --min) MIN="$2"; shift 2 ;;
        --max) MAX="$2"; shift 2 ;;
        --min=*) MIN="${1#--min=}"; shift ;;
        --max=*) MAX="${1#--max=}"; shift ;;
        *) positional+=("$1"); shift ;;
    esac
done
set -- "${positional[@]}"

FILE_GLOBS="${1:-}"
KEYWORDS="${2:-}"

[ -f "$PATHS" ] || { echo "ERROR: $PATHS not found" >&2; exit 1; }

results=""

# 1. paths.json 反查（applies_to glob 命中）
if [ -n "$FILE_GLOBS" ]; then
    IFS=',' read -ra globs <<< "$FILE_GLOBS"
    for f in "${globs[@]}"; do
        f_trim=$(echo "$f" | tr -d ' ')
        # 简单匹配：skill 的 glob 出现在用户传入的 path 段里（双向 substring）
        hit=$(jq -r --arg g "$f_trim" '.[] | select(.glob as $sg | ($g | contains($sg)) or ($sg | contains($g))) | .skill' "$PATHS" 2>/dev/null || true)
        results="$results
$hit"
    done
fi

# 2. 关键字命中
if [ -n "$KEYWORDS" ]; then
    for k in $KEYWORDS; do
        k_lc=$(echo "$k" | tr '[:upper:]' '[:lower:]')
        hit=$(jq -r --arg k "$k_lc" '.[$k] // [] | .[]' "$KW" 2>/dev/null || true)
        results="$results
$hit"
    done
fi

# 3. 从 file_globs 路径段推 kind（如 src/api/*.py → 找 lang/python）
if [ -n "$FILE_GLOBS" ]; then
    if echo "$FILE_GLOBS" | grep -qE '\.tsx?$|\.jsx?$'; then
        hit=$(jq -r '.[] | select(.kind=="lang" and (.dir | contains("typescript") or contains("javascript"))) | .path' "$TREE" | head -3)
        results="$results
$hit"
    fi
    if echo "$FILE_GLOBS" | grep -qE '\.py$'; then
        hit=$(jq -r '.[] | select(.kind=="lang" and (.dir | contains("python"))) | .path' "$TREE" | head -3)
        results="$results
$hit"
    fi
    if echo "$FILE_GLOBS" | grep -qE '\.sql$'; then
        hit=$(jq -r '.[] | select(.kind=="lang" and (.dir | contains("sql"))) | .path' "$TREE" | head -3)
        results="$results
$hit"
    fi
fi

final=$(echo "$results" | grep -v '^$' | sort -u)

# --- --min / --max 夹逼 ------------------------------------------------------
if [ -n "$MIN" ] || [ -n "$MAX" ]; then
    have=$(echo "$final" | grep -c '.' || true)
    # 补齐到 min：先放宽关键字（已在 results），再从全 tree 按 kind 优先级兜底
    if [ -n "$MIN" ] && [ "$have" -lt "$MIN" ]; then
        # 兜底池：habit/code-quality + design-pattern + framework + lang（通用度高的在前）
        pad=$(jq -r '.[]
            | select((.kind=="habit") or (.kind=="design-pattern") or (.kind=="framework") or (.kind=="lang"))
            | .path' "$TREE" 2>/dev/null | sort -u)
        final=$(printf '%s\n%s\n' "$final" "$pad" | grep -v '^$' | awk '!seen[$0]++')
    fi
    # 截断到 max
    if [ -n "$MAX" ]; then
        final=$(echo "$final" | grep -v '^$' | head -n "$MAX")
    fi
fi

echo "$final" | grep -v '^$'
