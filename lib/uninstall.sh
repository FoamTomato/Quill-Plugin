#!/usr/bin/env bash
#
# uninstall.sh — 卸载 Quill 在**当前项目**留下的产物
#
# 默认（不传 flag）：
#   - .quill/                          私有运行产物
#   - .quill-config.json               团队共享配置
#   - QUILL.md                         能力索引看板
#   - .gitignore 内由 config-write.sh 追加的 3 行块
# --global：额外清
#   - ~/.claude/quill-skills/          全局 skill bundle（所有项目共享）
# --yes：跳过 y/N 确认
# --dry-run：只列清单不动文件
#
# 收尾尝试调：
#   claude plugin uninstall quill
#   claude plugin marketplace remove quill
# 如果 claude CLI 不在 PATH 就只打印命令让用户手动跑。

set -uo pipefail

GLOBAL=0
ASSUME_YES=0
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --global)  GLOBAL=1; shift ;;
        --yes|-y)  ASSUME_YES=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help)
            sed -n '3,20p' "$0"
            exit 0
            ;;
        *) echo "unknown arg: $1" >&2; exit 1 ;;
    esac
done

# --- 1. 收集清单 ------------------------------------------------------------

declare -a TARGETS=()
declare -a NOTES=()

[ -d ".quill" ]              && TARGETS+=("./.quill/")              && NOTES+=("私有运行产物 (gitignore 内)")
[ -f ".quill-config.json" ]  && TARGETS+=("./.quill-config.json")    && NOTES+=("团队共享配置 (.gitignore 之外，受 git 管)")
[ -f "QUILL.md" ]            && TARGETS+=("./QUILL.md")              && NOTES+=("能力索引看板")

GITIGNORE_HIT=0
if [ -f ".gitignore" ] && grep -qFx "# Quill plugin private runtime" .gitignore && grep -qFx ".quill/" .gitignore; then
    GITIGNORE_HIT=1
    TARGETS+=(".gitignore (Quill 块)")
    NOTES+=("精确移除 3 行 (空行 + 注释 + .quill/)")
fi

GLOBAL_DIR="$HOME/.claude/quill-skills"
if [ "$GLOBAL" = "1" ] && [ -d "$GLOBAL_DIR" ]; then
    TARGETS+=("$GLOBAL_DIR")
    NOTES+=("全局 skill bundle 缓存 (所有项目共享)")
fi

# --- 2. 打印清单 ------------------------------------------------------------

if [ "${#TARGETS[@]}" = "0" ]; then
    echo "✅ 当前项目没有 Quill 产物 — 没有需要清的东西。"
    [ "$GLOBAL" != "1" ] && [ -d "$GLOBAL_DIR" ] && \
        echo "   (注：~/.claude/quill-skills/ 仍存在，加 --global 清它)"
else
    echo "将清理以下项："
    for i in "${!TARGETS[@]}"; do
        printf "  - %s\n    %s\n" "${TARGETS[$i]}" "${NOTES[$i]}"
    done
fi

# --- 3. dry-run 直接返回 ----------------------------------------------------

if [ "$DRY_RUN" = "1" ]; then
    echo ""
    echo "[dry-run] 未做任何改动。"
    exit 0
fi

# --- 4. 用户确认 ------------------------------------------------------------

if [ "${#TARGETS[@]}" != "0" ] && [ "$ASSUME_YES" != "1" ]; then
    printf "确认清理？[y/N]: "
    read -r REPLY
    case "$REPLY" in
        y|Y|yes|YES) ;;
        *) echo "已取消。"; exit 0 ;;
    esac
fi

# --- 5. 执行删除 ------------------------------------------------------------

removed=0

if [ -d ".quill" ]; then rm -rf .quill && removed=$((removed+1)); fi
if [ -f ".quill-config.json" ]; then rm -f .quill-config.json && removed=$((removed+1)); fi
if [ -f "QUILL.md" ]; then rm -f QUILL.md && removed=$((removed+1)); fi

if [ "$GITIGNORE_HIT" = "1" ]; then
    # 精确移除 3 行块。策略：把 .gitignore 整文件读进来，按行扫描，
    # 命中 "# Quill plugin private runtime" 且下一行是 ".quill/" 时，
    # 把这两行 + 前一行（如果是空行）一起跳过。
    python3 - <<'PY'
import re
from pathlib import Path
p = Path(".gitignore")
lines = p.read_text().splitlines(keepends=False)
out = []
i = 0
while i < len(lines):
    if lines[i] == "# Quill plugin private runtime" and i + 1 < len(lines) and lines[i+1] == ".quill/":
        # 如果 out 末尾是空行，连它一起丢
        if out and out[-1] == "":
            out.pop()
        i += 2  # 跳过 注释 + .quill/
        continue
    out.append(lines[i])
    i += 1
# 收尾换行
p.write_text("\n".join(out) + ("\n" if out else ""))
PY
    removed=$((removed+1))
fi

if [ "$GLOBAL" = "1" ] && [ -d "$GLOBAL_DIR" ]; then
    rm -rf "$GLOBAL_DIR" && removed=$((removed+1))
fi

echo ""
echo "✅ 已清理 $removed 项。"

# --- 6. 调 claude CLI 卸 plugin --------------------------------------------

if command -v claude >/dev/null 2>&1; then
    echo ""
    echo "尝试调 claude CLI 卸载 plugin..."
    if claude plugin list 2>/dev/null | grep -q "quill@quill"; then
        claude plugin uninstall quill 2>&1 || true
    else
        echo "  (plugin 已不在 list 里，跳过)"
    fi
    if claude plugin marketplace list 2>/dev/null | awk '/^  ❯ /{print $2}' | grep -qx "quill"; then
        claude plugin marketplace remove quill 2>&1 || true
    else
        echo "  (marketplace 已不在 list 里，跳过)"
    fi
else
    echo ""
    echo "claude CLI 不在 PATH。请手动跑："
    echo "    claude plugin uninstall quill"
    echo "    claude plugin marketplace remove quill"
fi

echo ""
echo "✅ Uninstall 完成。"
