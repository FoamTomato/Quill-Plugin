#!/usr/bin/env bash
# skill-bootstrap.sh — 首次下载 skill bundle + sha256 校验 + 解包到 ~/.claude/quill-skills/
#
# 用法：
#   bash skill-bootstrap.sh                       # 默认走官方源（带 GitHub fallback）
#   bash skill-bootstrap.sh --source <url>        # 指定 URL
#   bash skill-bootstrap.sh --local <dir>         # 从本地目录 rsync（开发联调用）
#
# 退出码：
#   0  成功
#   1  下载/解包失败
#   2  依赖缺失

set -e

LOCAL_DIR="$HOME/.claude/quill-skills"
# PLUGIN_ROOT 兜底：claude-code 注入 → plugin 缓存最新版 → 当前 pwd（dev）
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
# 版本号 = main 分支最新 commit 短 SHA（与 skill-update.sh --check-only 同源，便于比对）
VERSION_API="https://api.github.com/repos/FoamTomato/Prompts-MCP/commits/main"

SOURCE=""
LOCAL_SRC=""

while [ $# -gt 0 ]; do
    case "$1" in
        --source) SOURCE="$2"; shift 2 ;;
        --local) LOCAL_SRC="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
done

for cmd in tar curl shasum; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd required" >&2; exit 2; }
done

mkdir -p "$LOCAL_DIR"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# --- 1. 拉取源 ----------------------------------------------------------------

if [ -n "$LOCAL_SRC" ]; then
    echo "[skill-bootstrap] local source: $LOCAL_SRC" >&2
    if [ ! -d "$LOCAL_SRC/skills" ]; then
        echo "ERROR: $LOCAL_SRC/skills not found" >&2
        exit 1
    fi
    # --exclude=style/：保护用户用 /quill:ui 作者化的本地风格 skill 不被上游同步删掉
    rsync -a --delete --exclude='style/' "$LOCAL_SRC/skills/" "$LOCAL_DIR/skills/"
    SRC_USED="local:$LOCAL_SRC"
else
    BUNDLE="$TMP_DIR/bundle.tar.gz"
    for URL in "${SOURCE:-$DEFAULT_SOURCE}" "$FALLBACK_SOURCE"; do
        echo "[skill-bootstrap] trying $URL" >&2
        if curl -fsSL --max-time 60 -o "$BUNDLE" "$URL"; then
            SRC_USED="$URL"
            break
        fi
        echo "[skill-bootstrap]   failed, try next" >&2
        rm -f "$BUNDLE"
    done

    if [ ! -s "$BUNDLE" ]; then
        echo "ERROR: all sources failed. Check network or use --local <dir>" >&2
        exit 1
    fi

    # 解包
    EXTRACT="$TMP_DIR/extract"
    mkdir -p "$EXTRACT"
    tar -xzf "$BUNDLE" -C "$EXTRACT"

    # 定位 skills/ 目录（兼容 GitHub fallback：prompts-mcp-main/skills/...）
    SKILLS_SRC=$(find "$EXTRACT" -maxdepth 3 -type d -name skills | head -1)
    if [ -z "$SKILLS_SRC" ]; then
        echo "ERROR: skills/ not found in bundle" >&2
        exit 1
    fi
    # --exclude=style/：同上，保护本地风格 skill
    rsync -a --delete --exclude='style/' "$SKILLS_SRC/" "$LOCAL_DIR/skills/"
fi

# --- 2. 合并 plugin 自带的 agents-src / prompts-src ----------------------------

if [ -d "$PLUGIN_ROOT/agents-src" ]; then
    mkdir -p "$LOCAL_DIR/agents"
    rsync -a --delete "$PLUGIN_ROOT/agents-src/" "$LOCAL_DIR/agents/"
fi
if [ -d "$PLUGIN_ROOT/prompts-src" ]; then
    mkdir -p "$LOCAL_DIR/prompts"
    rsync -a --delete "$PLUGIN_ROOT/prompts-src/" "$LOCAL_DIR/prompts/"
fi

# --- 2.5 把 agent 文件软链到 ~/.claude/agents/ -------------------------------
# Claude Code 只扫 ~/.claude/agents/ 和 <project>/.claude/agents/ 来注册 subagent_type，
# 所以这里给每个 agent md 建一条 quill-<name>.md 软链，让它们出现在 Agent 工具的可选列表里。
# 用前缀隔离命名空间，uninstall 时按前缀 unlink。
if [ -d "$LOCAL_DIR/agents" ]; then
    AGENTS_LINK_DIR="$HOME/.claude/agents"
    mkdir -p "$AGENTS_LINK_DIR"
    # 先清理悬空死链：若某 quill-<name>.md 软链指向已不存在的源（agent 改名/删除后），
    # 删之免得 Claude 注册到坏 agent。
    pruned=0
    for link in "$AGENTS_LINK_DIR"/quill-*.md; do
        [ -L "$link" ] || continue
        if [ ! -e "$link" ]; then          # 符号链接的目标已不存在
            rm -f "$link"; pruned=$((pruned+1))
        fi
    done
    [ "$pruned" -gt 0 ] && echo "[skill-bootstrap] pruned $pruned dead agent symlink(s)" >&2
    linked=0
    for src in "$LOCAL_DIR"/agents/*.md; do
        [ -f "$src" ] || continue
        base="$(basename "$src")"
        # 下划线开头的是共享 reference（如 _step-protocol.md），不当 agent 注册
        case "$base" in _*) continue ;; esac
        dst="$AGENTS_LINK_DIR/quill-$base"
        # 已存在且是指向我们 bundle 的符号链接 → 跳过；指向别处或是普通文件 → 不动，避免覆盖用户的
        if [ -L "$dst" ]; then
            current="$(readlink "$dst")"
            if [ "$current" = "$src" ]; then
                continue
            fi
            ln -sfn "$src" "$dst"
        elif [ -e "$dst" ]; then
            echo "[skill-bootstrap]   skip $dst (exists, not our symlink)" >&2
            continue
        else
            ln -s "$src" "$dst"
        fi
        linked=$((linked+1))
    done
    echo "[skill-bootstrap] linked $linked agent(s) into $AGENTS_LINK_DIR/ (prefix: quill-)" >&2
fi

# --- 3. 写 manifest.json -----------------------------------------------------

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
MANIFEST="$LOCAL_DIR/manifest.json"

# 收集所有 skill md + agent md + prompt md 的 sha256
files_json=$(
    cd "$LOCAL_DIR"
    find skills agents prompts -type f \( -name '*.md' -o -name '*.txt' \) 2>/dev/null \
      | sort \
      | while read -r f; do
            sha=$(shasum -a 256 "$f" | awk '{print $1}')
            printf '{"path":"%s","sha256_original":"%s","user_modified":false}\n' "$f" "$sha"
        done \
      | jq -s '.'
)

# 版本号：优先取 main 最新 commit 短 SHA（与 update --check-only 同源可直接比对）；
# 离线 / --local（无对应远端 SHA）时退回日期标记。
# 不整体喂 jq：commit message 可能含未转义控制字符；直接 grep 顶层首个 sha。
BUNDLE_VERSION=$(curl -sf --max-time 5 \
    -H "Accept: application/vnd.github+json" "$VERSION_API" 2>/dev/null \
    | grep -m1 '"sha"' | grep -oE '[0-9a-f]{40}' | head -1 | cut -c1-7)
[ -z "$BUNDLE_VERSION" ] && BUNDLE_VERSION="main-$(date +%Y%m%d)"

cat > "$MANIFEST" <<EOF
{
  "version": "$BUNDLE_VERSION",
  "downloaded_at": "$NOW",
  "source": "$SRC_USED",
  "files": ${files_json}
}
EOF

echo "[skill-bootstrap] manifest written: $MANIFEST" >&2

# --- 4. 建索引 ---------------------------------------------------------------

bash "$PLUGIN_ROOT/lib/build-skill-index.sh"

# --- 5. 报告 -----------------------------------------------------------------

SKILL_COUNT=$(find "$LOCAL_DIR/skills" -name '*.md' -type f | wc -l | tr -d ' ')
echo "[skill-bootstrap] ✅ Done. $SKILL_COUNT skill files installed at $LOCAL_DIR"
