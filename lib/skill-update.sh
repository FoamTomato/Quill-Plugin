#!/usr/bin/env bash
# skill-update.sh — 增量更新 skill bundle，保护用户改过的文件
#
# 用法：
#   bash skill-update.sh                  # 升级
#   bash skill-update.sh --check-only     # 只检查不更新（异步在 bootstrap 跑）
#   bash skill-update.sh --source <url>   # 指定源
#   bash skill-update.sh --local <dir>    # 本地源（开发联调）
#
# 用户改动保护策略：
#   manifest.json 记录每个文件首次下载时的 sha256_original
#   更新前对每个文件比对本地实际 sha256：
#     - 本地 sha == sha256_original → 未改过，正常更新
#     - 本地 sha != sha256_original → 用户改过，跳过（无论远端是否变）
#   被跳过的文件加入 manifest.skipped[]，报告给用户

set -e

LOCAL_DIR="$HOME/.claude/quill-skills"
if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -d "$CLAUDE_PLUGIN_ROOT" ]; then
    PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
else
    PLUGIN_ROOT=$(ls -1d "$HOME"/.claude/plugins/cache/*/quill/*/ 2>/dev/null \
                    | sort -V | tail -1 | sed 's:/*$::')
    [ -z "$PLUGIN_ROOT" ] && [ -f ./.claude-plugin/plugin.json ] && PLUGIN_ROOT="$(pwd)"
fi
[ -z "$PLUGIN_ROOT" ] && { echo "ERROR: cannot resolve plugin root" >&2; exit 2; }
DEFAULT_SOURCE="https://github.com/FoamTomato/Prompts-MCP/archive/refs/heads/main.tar.gz"
FALLBACK_SOURCE="https://codeload.github.com/FoamTomato/Prompts-MCP/tar.gz/refs/heads/main"
# GitHub tarball 无 version.txt：版本探测用 main 分支最新 commit SHA（短）。
# 探测失败（离线/限流）时 --check-only 静默跳过，不阻塞。
VERSION_URL="https://api.github.com/repos/FoamTomato/Prompts-MCP/commits/main"

CHECK_ONLY=0
SOURCE=""
LOCAL_SRC=""

while [ $# -gt 0 ]; do
    case "$1" in
        --check-only) CHECK_ONLY=1; shift ;;
        --source) SOURCE="$2"; shift 2 ;;
        --local) LOCAL_SRC="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
done

MANIFEST="$LOCAL_DIR/manifest.json"
[ -f "$MANIFEST" ] || { echo "ERROR: no manifest, run skill-bootstrap.sh first" >&2; exit 1; }

CURRENT_VERSION=$(jq -r '.version // "unknown"' "$MANIFEST")

# --- check-only：只比对远端版本 -----------------------------------------------

if [ "$CHECK_ONLY" = "1" ]; then
    # GitHub commits API → 取 main 最新 commit 短 SHA 当远端版本。
    # 不整体喂 jq：commit message 里可能含未转义控制字符会让 jq 解析失败，
    # 故直接 grep 顶层第一个 "sha" 字段（该端点首行即 commit SHA）。
    REMOTE_VERSION=$(curl -sf --max-time 5 \
        -H "Accept: application/vnd.github+json" "$VERSION_URL" 2>/dev/null \
        | grep -m1 '"sha"' | grep -oE '[0-9a-f]{40}' | head -1 | cut -c1-7)
    if [ -z "$REMOTE_VERSION" ]; then
        # 离线 / 限流 / 远端未就绪，静默退出（不阻塞主流程）
        exit 0
    fi
    if [ "$REMOTE_VERSION" != "$CURRENT_VERSION" ]; then
        echo "💡 skill 库有新版本 $REMOTE_VERSION（当前 $CURRENT_VERSION），跑 /quill update-skills 升级"
    fi
    exit 0
fi

# --- 正式更新 ----------------------------------------------------------------

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# 1. 拉新 bundle 到 /tmp
EXTRACT="$TMP_DIR/extract"
mkdir -p "$EXTRACT"

if [ -n "$LOCAL_SRC" ]; then
    echo "[skill-update] local source: $LOCAL_SRC" >&2
    rsync -a "$LOCAL_SRC/skills/" "$EXTRACT/skills/"
else
    BUNDLE="$TMP_DIR/bundle.tar.gz"
    for URL in "${SOURCE:-$DEFAULT_SOURCE}" "$FALLBACK_SOURCE"; do
        echo "[skill-update] trying $URL" >&2
        if curl -fsSL --max-time 60 -o "$BUNDLE" "$URL"; then
            tar -xzf "$BUNDLE" -C "$EXTRACT"
            break
        fi
    done
    [ ! -s "$BUNDLE" ] && { echo "ERROR: download failed"; exit 1; }
    SKILLS_SRC=$(find "$EXTRACT" -maxdepth 3 -type d -name skills | head -1)
    [ -z "$SKILLS_SRC" ] && { echo "ERROR: skills/ not in bundle"; exit 1; }
    # 标准化到 $EXTRACT/skills/
    [ "$SKILLS_SRC" != "$EXTRACT/skills" ] && { rm -rf "$EXTRACT/skills"; mv "$SKILLS_SRC" "$EXTRACT/skills"; }
fi

# 2. 合并 plugin agents-src / prompts-src 到 EXTRACT
[ -d "$PLUGIN_ROOT/agents-src" ] && rsync -a "$PLUGIN_ROOT/agents-src/" "$EXTRACT/agents/"
[ -d "$PLUGIN_ROOT/prompts-src" ] && rsync -a "$PLUGIN_ROOT/prompts-src/" "$EXTRACT/prompts/"

# 3. 逐文件 diff：未改的覆盖，改过的跳过
declare -a SKIPPED=()
declare -a UPDATED=()
declare -a ADDED=()
declare -a REMOVED=()

# 当前 manifest 中每个文件的 sha256_original
TMP_NEW_FILES_JSON="$TMP_DIR/new_files.json"
echo "[]" > "$TMP_NEW_FILES_JSON"

# 遍历 EXTRACT 里的所有 .md / .txt
while IFS= read -r rel; do
    src="$EXTRACT/$rel"
    dst="$LOCAL_DIR/$rel"

    sha_new=$(shasum -a 256 "$src" | awk '{print $1}')

    if [ -f "$dst" ]; then
        # 已有，比对本地 sha 和 manifest.sha256_original
        sha_local=$(shasum -a 256 "$dst" | awk '{print $1}')
        sha_orig=$(jq -r --arg p "$rel" '.files[] | select(.path==$p) | .sha256_original // ""' "$MANIFEST")

        if [ -n "$sha_orig" ] && [ "$sha_local" != "$sha_orig" ]; then
            # 用户改过 → 跳过
            SKIPPED+=("$rel")
        elif [ "$sha_local" != "$sha_new" ]; then
            # 未改且有新版 → 更新
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            UPDATED+=("$rel")
            sha_orig="$sha_new"
        else
            # 内容一致，无操作
            [ -z "$sha_orig" ] && sha_orig="$sha_new"
        fi
    else
        # 新增
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        ADDED+=("$rel")
        sha_orig="$sha_new"
    fi

    jq --arg p "$rel" --arg s "$sha_orig" \
       '. += [{"path":$p,"sha256_original":$s,"user_modified":false}]' \
       "$TMP_NEW_FILES_JSON" > "$TMP_NEW_FILES_JSON.tmp" && mv "$TMP_NEW_FILES_JSON.tmp" "$TMP_NEW_FILES_JSON"

done < <(cd "$EXTRACT" && find skills agents prompts -type f \( -name '*.md' -o -name '*.txt' \) 2>/dev/null | sort)

# 4. 标记被跳过的为 user_modified=true
for rel in "${SKIPPED[@]}"; do
    jq --arg p "$rel" '(.[] | select(.path==$p) | .user_modified) = true' \
       "$TMP_NEW_FILES_JSON" > "$TMP_NEW_FILES_JSON.tmp" && mv "$TMP_NEW_FILES_JSON.tmp" "$TMP_NEW_FILES_JSON"
done

# 5. 检测 REMOVED（本地有但 EXTRACT 没有的文件）
while IFS= read -r rel; do
    if [ ! -f "$EXTRACT/$rel" ]; then
        # 远端删了，但用户可能改过 → 不主动删，记下来让用户决定
        REMOVED+=("$rel")
    fi
done < <(cd "$LOCAL_DIR" && find skills agents prompts -type f \( -name '*.md' -o -name '*.txt' \) 2>/dev/null | sort)

# 6. 写新 manifest
NEW_VERSION="main-$(date +%Y%m%d)"
[ -n "$LOCAL_SRC" ] && SRC_USED="local:$LOCAL_SRC" || SRC_USED="${SOURCE:-$DEFAULT_SOURCE}"

cat > "$MANIFEST" <<EOF
{
  "version": "$NEW_VERSION",
  "downloaded_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source": "$SRC_USED",
  "files": $(cat "$TMP_NEW_FILES_JSON"),
  "skipped": $(printf '%s\n' "${SKIPPED[@]}" | jq -R . | jq -s .),
  "updated_count": ${#UPDATED[@]},
  "added_count": ${#ADDED[@]},
  "skipped_count": ${#SKIPPED[@]},
  "removed_candidates_count": ${#REMOVED[@]}
}
EOF

# 7. 重建索引
bash "$PLUGIN_ROOT/lib/build-skill-index.sh"

# 8. 报告
echo ""
echo "=== Skill Update Report ==="
echo "version: $CURRENT_VERSION → $NEW_VERSION"
echo "updated:  ${#UPDATED[@]} files"
echo "added:    ${#ADDED[@]} files"
echo "skipped:  ${#SKIPPED[@]} files (user modified, preserved)"
echo "removed candidates: ${#REMOVED[@]} files (远端已删但本地保留，请手动评估)"

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo ""
    echo "📌 Skipped (your changes preserved):"
    for f in "${SKIPPED[@]}"; do echo "   - $f"; done
fi
if [ ${#REMOVED[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  Removed candidates (远端已删除，本地保留)："
    for f in "${REMOVED[@]}"; do echo "   - $f"; done
fi
echo ""
echo "✅ Done"
