#!/usr/bin/env bash
# quill-detect.sh — 只读进度探针，给 /quill:run 编排器做 auto-judge 的唯一数据源
#
# 用法：
#   bash quill-detect.sh            # 打印 KEY=VALUE（可 eval 注入变量）
#   bash quill-detect.sh --json     # 打印 JSON
#
# 设计铁律：只查存在性 + grep -c 计数，绝不 dump 任何文档/报告全文。
# 依赖 config-bootstrap 已 export 的 QUILL_PRD_DIR / QUILL_PRIVATE_DIR；
# 未 export 时退回常见默认，缺啥算 0，不报错（探针不该中断编排）。

set -u

PRD_DIR="${QUILL_PRD_DIR:-}"
PRIV_DIR="${QUILL_PRIVATE_DIR:-.quill}"
SKILL_DIR="${QUILL_SKILL_DIR:-$HOME/.claude/quill-skills}"

# PRD 目录兜底：没 export 就扫常见位置（只读，找不到就空）
if [ -z "$PRD_DIR" ]; then
    for c in docs/prd docs/PRD prd .quill/prd; do
        [ -d "$c" ] && { PRD_DIR="$c"; break; }
    done
fi

exists() { [ -f "$1" ] && echo 1 || echo 0; }

PRD_FILE="$PRD_DIR/product-requirements.md"
HLD_FILE="$PRD_DIR/high-level-design.md"
UI_SPEC="$PRD_DIR/ui-spec.md"
FLOW_FILE="$PRD_DIR/flow.drawio"

HAS_PRD=$(exists "$PRD_FILE")
HAS_HLD=$(exists "$HLD_FILE")
HAS_UI_SPEC=$(exists "$UI_SPEC")
HAS_FLOW=$(exists "$FLOW_FILE")

# requirement-*.md（prd-lite 精炼器产物）数量
REQ_BRIEFS=0
if [ -n "$PRD_DIR" ] && [ -d "$PRD_DIR" ]; then
    REQ_BRIEFS=$(find "$PRD_DIR" -maxdepth 1 -name 'requirement-*.md' -type f 2>/dev/null | wc -l | tr -d ' ')
fi

# HLD §九 checklist 未勾项（0 = 全做完）
HLD_UNCHECKED=0
[ "$HAS_HLD" = "1" ] && HLD_UNCHECKED=$(grep -c '^- \[ \]' "$HLD_FILE" 2>/dev/null || echo 0)

# UI 风格 skill（ui 工厂产物）
HAS_STYLE_SKILL=0
ls "$SKILL_DIR"/skills/style/*/index.md >/dev/null 2>&1 && HAS_STYLE_SKILL=1

# 批次：.quill/runs/*
RUNS_TOTAL=0
LATEST_BATCH="-"
LATEST_DEV_DONE=0
LATEST_TEST_PASS="-"
if [ -d "$PRIV_DIR/runs" ]; then
    RUNS_TOTAL=$(find "$PRIV_DIR/runs" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    LATEST_BATCH=$(ls -1t "$PRIV_DIR/runs" 2>/dev/null | head -1)
    [ -z "$LATEST_BATCH" ] && LATEST_BATCH="-"
    if [ "$LATEST_BATCH" != "-" ]; then
        [ -f "$PRIV_DIR/runs/$LATEST_BATCH/dev-output.md" ] && LATEST_DEV_DONE=1
        # 三维报告都 PASS 才算 PASS；有报告但任一非 PASS = 0；无报告 = -
        reports=$(find "$PRIV_DIR/runs/$LATEST_BATCH/test-reports" -name 'batch-*.md' 2>/dev/null)
        if [ -n "$reports" ]; then
            LATEST_TEST_PASS=1
            while IFS= read -r r; do
                head -1 "$r" 2>/dev/null | grep -q 'PASS' || LATEST_TEST_PASS=0
            done <<< "$reports"
        fi
    fi
fi

# git 未提交改动
GIT_DIRTY=0
GIT_DIFF_FILES=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_DIRTY=$(git status --porcelain 2>/dev/null | grep -c '.' || echo 0)
    GIT_DIFF_FILES=$(git diff --name-only 2>/dev/null | grep -c '.' || echo 0)
fi

if [ "${1:-}" = "--json" ]; then
    cat <<EOF
{
  "HAS_PRD": $HAS_PRD,
  "HAS_HLD": $HAS_HLD,
  "HLD_UNCHECKED": $HLD_UNCHECKED,
  "HAS_UI_SPEC": $HAS_UI_SPEC,
  "HAS_FLOW": $HAS_FLOW,
  "HAS_STYLE_SKILL": $HAS_STYLE_SKILL,
  "REQ_BRIEFS": $REQ_BRIEFS,
  "RUNS_TOTAL": $RUNS_TOTAL,
  "LATEST_BATCH": "$LATEST_BATCH",
  "LATEST_DEV_DONE": $LATEST_DEV_DONE,
  "LATEST_TEST_PASS": "$LATEST_TEST_PASS",
  "GIT_DIRTY": $GIT_DIRTY,
  "GIT_DIFF_FILES": $GIT_DIFF_FILES
}
EOF
else
    cat <<EOF
HAS_PRD=$HAS_PRD
HAS_HLD=$HAS_HLD
HLD_UNCHECKED=$HLD_UNCHECKED
HAS_UI_SPEC=$HAS_UI_SPEC
HAS_FLOW=$HAS_FLOW
HAS_STYLE_SKILL=$HAS_STYLE_SKILL
REQ_BRIEFS=$REQ_BRIEFS
RUNS_TOTAL=$RUNS_TOTAL
LATEST_BATCH=$LATEST_BATCH
LATEST_DEV_DONE=$LATEST_DEV_DONE
LATEST_TEST_PASS=$LATEST_TEST_PASS
GIT_DIRTY=$GIT_DIRTY
GIT_DIFF_FILES=$GIT_DIFF_FILES
EOF
fi