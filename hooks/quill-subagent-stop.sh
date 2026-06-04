#!/usr/bin/env bash
#
# Quill SubagentStop hook · 自动收集 agentId + 写 main-log
#
# 触发时机：每个 quill-* subagent 收工后。
# 职责：把刚结束的 sub-agent agentId 写入当前 BATCH 的 agent-ids.json + main-log.md。
# MUST exit 0（hook 失败不能阻塞 Claude 主流程）。

set -u

INPUT=$(cat 2>/dev/null || echo '{}')

SUBAGENT=$(printf '%s' "$INPUT" | jq -r '.subagent_name // .tool_input.subagent_type // .agent_name // empty' 2>/dev/null || echo "")
AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // .subagent_id // empty' 2>/dev/null || echo "")

if [ -z "$AGENT_ID" ]; then
  LATEST=$(find "$HOME/.claude/projects/" -name "agent-*.meta.json" -type f -print0 2>/dev/null \
    | xargs -0 stat -f '%m %N' 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)
  if [ -n "$LATEST" ]; then
    AGENT_ID=$(basename "$LATEST" | sed -E 's/^agent-(.+)\.meta\.json$/\1/')
  fi
fi

# 只处理 Quill 自己的 subagent
case "${SUBAGENT:-}" in
  dev-planner|dev-coder|test-tester-prd|test-tester-ui|test-tester-lint|prd-writer-full|prd-writer-lite|hld-writer-full|hld-writer-lite|flow-writer|ui-style-author) ;;
  *) exit 0 ;;
esac

[ -z "$AGENT_ID" ] && exit 0

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$REPO_ROOT" ] && exit 0

PRIV_DIR="$REPO_ROOT/.quill"
[ ! -d "$PRIV_DIR" ] && exit 0

# 找最新的 BATCH 目录（按 mtime）
BATCH_DIR=$(ls -1dt "$PRIV_DIR"/runs/*/ 2>/dev/null | head -1)

# 文档类 writer 在非 dev 流程中不一定有 BATCH，写到 logs/agent-ids.json 兜底
if [ -z "$BATCH_DIR" ]; then
  mkdir -p "$PRIV_DIR/logs"
  IDS_FILE="$PRIV_DIR/logs/agent-ids.json"
  LOG_FILE="$PRIV_DIR/logs/main-log.md"
else
  BATCH_DIR="${BATCH_DIR%/}"
  IDS_FILE="$BATCH_DIR/agent-ids.json"
  LOG_FILE="$BATCH_DIR/main-log.md"
fi

if [ ! -f "$IDS_FILE" ]; then
  echo '{"dev":null,"dev_history":{},"testers":{"prd":null,"ui":null,"lint":null},"planner_history":[],"doc_chain":{"prd_writer_full":null,"prd_writer_lite":null,"hld_writer_full":null,"hld_writer_lite":null,"flow_writer":null},"ui_style_author":null}' > "$IDS_FILE"
fi

TS=$(date +"%y%m%d %H%M")

case "$SUBAGENT" in
  dev-coder)
    tmp=$(mktemp)
    jq --arg id "$AGENT_ID" '.dev = $id' "$IDS_FILE" > "$tmp" && mv "$tmp" "$IDS_FILE"
    echo "[$TS] SubagentStop dev-coder → DEV_ID=$AGENT_ID" >> "$LOG_FILE"
    ;;
  test-tester-prd|test-tester-ui|test-tester-lint)
    DIM="${SUBAGENT#test-tester-}"
    tmp=$(mktemp)
    jq --arg id "$AGENT_ID" --arg dim "$DIM" '.testers[$dim] = $id' "$IDS_FILE" > "$tmp" && mv "$tmp" "$IDS_FILE"
    echo "[$TS] SubagentStop $SUBAGENT → TESTER_${DIM}_ID=$AGENT_ID" >> "$LOG_FILE"
    ;;
  dev-planner)
    tmp=$(mktemp)
    jq --arg id "$AGENT_ID" '.planner_history += [$id]' "$IDS_FILE" > "$tmp" && mv "$tmp" "$IDS_FILE"
    echo "[$TS] SubagentStop dev-planner (one-shot, id=$AGENT_ID)" >> "$LOG_FILE"
    ;;
  prd-writer-full|prd-writer-lite|hld-writer-full|hld-writer-lite|flow-writer)
    KEY=$(echo "$SUBAGENT" | tr '-' '_')
    tmp=$(mktemp)
    jq --arg id "$AGENT_ID" --arg k "$KEY" '.doc_chain[$k] = $id' "$IDS_FILE" > "$tmp" && mv "$tmp" "$IDS_FILE"
    echo "[$TS] SubagentStop $SUBAGENT → id=$AGENT_ID" >> "$LOG_FILE"
    ;;
  ui-style-author)
    tmp=$(mktemp)
    jq --arg id "$AGENT_ID" '.ui_style_author = $id' "$IDS_FILE" > "$tmp" && mv "$tmp" "$IDS_FILE"
    echo "[$TS] SubagentStop ui-style-author → id=$AGENT_ID" >> "$LOG_FILE"
    ;;
esac

exit 0
