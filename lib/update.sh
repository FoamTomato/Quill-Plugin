#!/usr/bin/env bash
# update.sh — 一键升级 Quill（plugin 仓库 + skill bundle + agent 软链）
#
# 用法：
#   bash update.sh                    # 默认：plugin + skills + 软链
#   bash update.sh --skills-only      # 只升级 skill bundle（等同 /quill:update-skills）
#   bash update.sh --plugin-only      # 只升级 plugin 仓库
#   bash update.sh --local <dir>      # skill bundle 走本地源（开发联调）
#
# 退出码：
#   0 全部成功
#   1 某一步失败
#   2 参数错 / 依赖缺失

set -e

PLUGIN_ONLY=0
SKILLS_ONLY=0
LOCAL_SRC=""

while [ $# -gt 0 ]; do
    case "$1" in
        --plugin-only) PLUGIN_ONLY=1; shift ;;
        --skills-only) SKILLS_ONLY=1; shift ;;
        --local) LOCAL_SRC="$2"; shift 2 ;;
        -h|--help) sed -n '2,11p' "$0" | sed 's/^# //; s/^#//'; exit 0 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

# --- 1. 升级 plugin 仓库（marketplace refresh + plugin update）-----------------

if [ "$SKILLS_ONLY" != "1" ]; then
    echo "=== [1/3] 升级 plugin 仓库 ==="
    if ! command -v claude >/dev/null 2>&1; then
        echo "⚠️  claude CLI 不在 PATH，跳过 plugin 升级。请手动跑："
        echo "    claude plugin marketplace update quill"
        echo "    claude plugin update quill@quill"
    else
        # 先刷 marketplace（拉新 commit 到 cache）
        if claude plugin marketplace list 2>/dev/null | awk '/^  ❯ /{print $2}' | grep -qx "quill"; then
            echo "[update] claude plugin marketplace update quill"
            claude plugin marketplace update quill || echo "⚠️  marketplace update 失败，继续"
        else
            echo "⚠️  marketplace 'quill' 未注册，跳过 marketplace update"
        fi

        # 再 update plugin
        if claude plugin list 2>/dev/null | grep -q "quill@quill"; then
            echo "[update] claude plugin update quill@quill"
            claude plugin update quill@quill || echo "⚠️  plugin update 失败，继续"
            echo "ℹ️  plugin 更新已应用，重启 Claude Code 后生效。"
        else
            echo "⚠️  plugin 'quill@quill' 未安装，跳过 plugin update"
        fi
    fi
    echo ""
fi

# --- 2. 解析 PLUGIN_ROOT（必须用 cache 里最新版，不要用旧的）-------------------

# 优先环境变量（在 claude 会话里跑时由 claude 注入指向当前 plugin 实例）；
# 否则从 cache 取最新版本目录。
if [ -n "$CLAUDE_PLUGIN_ROOT" ] && [ -d "$CLAUDE_PLUGIN_ROOT" ]; then
    PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
else
    PLUGIN_ROOT=$(ls -1d "$HOME"/.claude/plugins/cache/*/quill/*/ 2>/dev/null \
                    | sort -V | tail -1 | sed 's:/*$::')
fi
[ -z "$PLUGIN_ROOT" ] || [ ! -d "$PLUGIN_ROOT" ] && {
    echo "ERROR: 无法定位 plugin root（cache 里没找到 quill），中止。" >&2
    exit 1
}
echo "[update] PLUGIN_ROOT = $PLUGIN_ROOT"

# --- 3. 升级 skill bundle（agents + prompts + skills）------------------------

if [ "$PLUGIN_ONLY" != "1" ]; then
    echo ""
    echo "=== [2/3] 升级 skill bundle ==="
    if [ -n "$LOCAL_SRC" ]; then
        bash "$PLUGIN_ROOT/lib/skill-update.sh" --local "$LOCAL_SRC"
    else
        bash "$PLUGIN_ROOT/lib/skill-update.sh"
    fi
fi

# --- 4. 重建 ~/.claude/agents/ 软链 ------------------------------------------

if [ "$PLUGIN_ONLY" != "1" ]; then
    echo ""
    echo "=== [3/3] 刷新 ~/.claude/agents/ 软链 ==="
    LOCAL_DIR="$HOME/.claude/quill-skills"
    AGENTS_LINK_DIR="$HOME/.claude/agents"
    mkdir -p "$AGENTS_LINK_DIR"

    # 先清掉指向 bundle 里已不存在的旧软链（防止 rename / 删除残留）
    cleaned=0
    for f in "$AGENTS_LINK_DIR"/quill-*.md; do
        [ -L "$f" ] || continue
        target="$(readlink "$f")"
        case "$target" in
            "$LOCAL_DIR/agents/"*)
                [ -f "$target" ] || { rm -f "$f"; cleaned=$((cleaned+1)); }
                ;;
        esac
    done
    [ "$cleaned" -gt 0 ] && echo "  清理 $cleaned 个失效软链"

    # 再建新软链（新增的 agent 会在这里被链上；下划线开头的跳过）
    linked=0; existed=0
    for src in "$LOCAL_DIR"/agents/*.md; do
        [ -f "$src" ] || continue
        base="$(basename "$src")"
        case "$base" in _*) continue ;; esac
        dst="$AGENTS_LINK_DIR/quill-$base"
        if [ -L "$dst" ]; then
            [ "$(readlink "$dst")" = "$src" ] && { existed=$((existed+1)); continue; }
            ln -sfn "$src" "$dst"; linked=$((linked+1))
        elif [ -e "$dst" ]; then
            echo "  skip (exists, not our symlink): $dst"
        else
            ln -s "$src" "$dst"; linked=$((linked+1))
        fi
    done
    echo "  新建/更新 $linked，已是最新 $existed"
fi

echo ""
echo "✅ Quill 升级完成。"
[ "$SKILLS_ONLY" != "1" ] && echo "ℹ️  plugin 改动要重启 Claude Code 才能生效（commands/、agent metadata）。"
