#!/usr/bin/env bash
# build-skill-index.sh — 把 ~/.claude/quill-skills/skills/ 编译成 index/*.json
#
# 产出：
#   index/tree.json     全树结构 [{path, title, dir, kind}]
#   index/paths.json    path glob → skill 反查表 [{glob, skill_paths:[...]}]
#   index/keywords.json 关键字倒排 {keyword: [skill_paths]}
#
# 简单粗暴策略（v0.2.0）：
#   - title 取每个 .md 的第一个 H1
#   - kind 取 skills/ 之后第一级目录（lang/framework/design-pattern/habit）
#   - keywords 取 skill 路径里的所有 path 段 + 第一行 H1 切词
#   - paths.json 由 skill 内的 "适用文件" 元注释扫描（v0.2.0 先空表，靠 keyword 匹配兜底）

set -e

LOCAL_DIR="$HOME/.claude/quill-skills"
INDEX_DIR="$LOCAL_DIR/index"
SKILLS_DIR="$LOCAL_DIR/skills"

[ -d "$SKILLS_DIR" ] || { echo "ERROR: $SKILLS_DIR not found" >&2; exit 1; }
mkdir -p "$INDEX_DIR"

# --- tree.json ----------------------------------------------------------------

tree_rows=$(
    cd "$LOCAL_DIR"
    find skills -type f -name '*.md' | sort | while read -r f; do
        rel="${f#skills/}"                          # framework/antd/form.md
        rel_noext="${rel%.md}"                      # framework/antd/form
        title=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' || echo "")
        kind=$(echo "$rel" | cut -d/ -f1)
        dir=$(dirname "$rel_noext")
        printf '{"path":"%s","title":%s,"dir":"%s","kind":"%s"}\n' \
            "$rel_noext" \
            "$(printf '%s' "${title:-$(basename "$rel_noext")}" | jq -R .)" \
            "$dir" \
            "$kind"
    done
)
echo "$tree_rows" | jq -s '.' > "$INDEX_DIR/tree.json"

# --- keywords.json ------------------------------------------------------------

kw_pairs=$(
    cd "$LOCAL_DIR"
    find skills -type f -name '*.md' | sort | while read -r f; do
        rel="${f#skills/}"; rel_noext="${rel%.md}"
        # 路径分段当 keyword
        for seg in $(echo "$rel_noext" | tr '/' ' '); do
            [ -z "$seg" ] && continue
            printf '%s\t%s\n' "$seg" "$rel_noext"
        done
        # H1 内中文/英文词（简单空格切分）
        title=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' | tr -cd 'A-Za-z0-9 一-龥' || echo "")
        for w in $title; do
            [ ${#w} -lt 2 ] && continue
            printf '%s\t%s\n' "$(echo "$w" | tr '[:upper:]' '[:lower:]')" "$rel_noext"
        done
    done
)

echo "$kw_pairs" | sort -u | awk -F'\t' '
{
    k=tolower($1); v=$2;
    if (map[k]) map[k]=map[k]"\n"v; else map[k]=v;
}
END {
    printf "{";
    first=1;
    for (k in map) {
        if (!first) printf ",";
        first=0;
        printf "\"%s\":[", k;
        n=split(map[k], arr, "\n");
        sfirst=1;
        for (i=1;i<=n;i++) {
            if (arr[i]=="") continue;
            if (!sfirst) printf ",";
            sfirst=0;
            printf "\"%s\"", arr[i];
        }
        printf "]";
    }
    printf "}";
}' > "$INDEX_DIR/keywords.json"

# --- paths.json ---------------------------------------------------------------
# v0.2.0：先扫描 skill md 顶部 frontmatter 的 applies_to 字段（若有）
# 没有就给一个空映射（skill-match 退回 keyword 匹配）

paths_rows=$(
    cd "$LOCAL_DIR"
    find skills -type f -name '*.md' | sort | while read -r f; do
        rel_noext="${f#skills/}"; rel_noext="${rel_noext%.md}"
        # 取前 10 行里的 applies_to: 字段
        applies=$(head -10 "$f" | grep -E '^applies_to:' | head -1 | sed 's/^applies_to://' | tr -d ' ')
        [ -z "$applies" ] && continue
        # 逗号分隔 glob
        echo "$applies" | tr ',' '\n' | while read -r glob; do
            [ -z "$glob" ] && continue
            printf '{"glob":"%s","skill":"%s"}\n' "$glob" "$rel_noext"
        done
    done
)
echo "${paths_rows:-}" | jq -s '.' > "$INDEX_DIR/paths.json"

TREE_N=$(jq 'length' "$INDEX_DIR/tree.json")
KW_N=$(jq 'length' "$INDEX_DIR/keywords.json")
PATH_N=$(jq 'length' "$INDEX_DIR/paths.json")
echo "[build-skill-index] tree=$TREE_N keywords=$KW_N paths=$PATH_N"
