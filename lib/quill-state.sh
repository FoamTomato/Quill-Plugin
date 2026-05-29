#!/usr/bin/env bash
# quill-state.sh — Quill 分步执行契约的 state.json 操作
#
# 用法：
#   bash quill-state.sh init <phase> <plan.json> [inputs.json]
#   bash quill-state.sh show <phase>
#   bash quill-state.sh next <phase>                 # 输出下一步 id；全部 done 输出 ALL_DONE
#   bash quill-state.sh mark <phase> <step_id> <status>   # status: in_progress|done|failed
#   bash quill-state.sh split <phase> <step_id> <new_title>  # 把当前步拆出一个新 pending step 插到后面
#   bash quill-state.sh note <phase> <text>          # 写一条 ≤500 字的跨步骤笔记
#
# 环境：
#   QUILL_PRIVATE_DIR 必填（默认 ./.quill）
#
# 退出码：0 OK / 1 业务错（如 phase 不存在）/ 2 参数错

set -e

PRIV="${QUILL_PRIVATE_DIR:-./.quill}"
STATE_DIR="$PRIV/state"
mkdir -p "$STATE_DIR"

cmd="${1:-}"
phase="${2:-}"

[ -z "$cmd" ] && { echo "usage: quill-state.sh <init|show|next|mark|split|note> ..." >&2; exit 2; }
[ -z "$phase" ] && { echo "ERROR: phase required" >&2; exit 2; }

FILE="$STATE_DIR/$phase.json"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required" >&2; exit 2; }

case "$cmd" in
    init)
        plan_file="${3:-}"
        inputs_file="${4:-}"
        [ -z "$plan_file" ] || [ ! -f "$plan_file" ] && { echo "ERROR: plan json file required" >&2; exit 2; }
        plan_json="$(cat "$plan_file")"
        if [ -n "$inputs_file" ] && [ -f "$inputs_file" ]; then
            inputs_json="$(cat "$inputs_file")"
        else
            inputs_json="{}"
        fi
        # plan_file 是 [{id, title}, ...]，补 status=pending
        plan_with_status="$(echo "$plan_json" | jq '[.[] | . + {status: "pending"}]')"
        jq -n \
            --arg phase "$phase" \
            --arg now "$NOW" \
            --argjson plan "$plan_with_status" \
            --argjson inputs "$inputs_json" \
            '{phase: $phase, version: 1, created_at: $now, updated_at: $now, plan: $plan, cursor: 1, inputs: $inputs, notes: ""}' \
            > "$FILE"
        echo "[state] init $phase ($(echo "$plan_with_status" | jq 'length') steps) → $FILE"
        ;;

    show)
        [ ! -f "$FILE" ] && { echo "ERROR: state not found: $FILE" >&2; exit 1; }
        cat "$FILE"
        ;;

    next)
        [ ! -f "$FILE" ] && { echo "NOT_INITIALIZED"; exit 0; }
        next_id="$(jq -r '[.plan[] | select(.status != "done")] | if length == 0 then "ALL_DONE" else .[0].id | tostring end' "$FILE")"
        echo "$next_id"
        ;;

    mark)
        step_id="${3:-}"
        status="${4:-}"
        [ -z "$step_id" ] || [ -z "$status" ] && { echo "ERROR: usage: mark <phase> <step_id> <status>" >&2; exit 2; }
        case "$status" in
            pending|in_progress|done|failed) ;;
            *) echo "ERROR: status must be pending|in_progress|done|failed" >&2; exit 2 ;;
        esac
        [ ! -f "$FILE" ] && { echo "ERROR: state not found" >&2; exit 1; }
        tmp="$(mktemp)"
        jq \
            --arg now "$NOW" \
            --arg sid "$step_id" \
            --arg st "$status" \
            '
            .updated_at = $now
            | .plan = (.plan | map(if (.id | tostring) == $sid then .status = $st else . end))
            | .cursor = (
                [.plan[] | select(.status != "done")] |
                if length == 0 then (.[-1].id // 0) else .[0].id end
              )
            ' "$FILE" > "$tmp"
        mv "$tmp" "$FILE"
        echo "[state] $phase step $step_id → $status"
        ;;

    split)
        step_id="${3:-}"
        new_title="${4:-}"
        [ -z "$step_id" ] || [ -z "$new_title" ] && { echo "ERROR: usage: split <phase> <step_id> <new_title>" >&2; exit 2; }
        [ ! -f "$FILE" ] && { echo "ERROR: state not found" >&2; exit 1; }
        tmp="$(mktemp)"
        new_id="${step_id}.5"
        jq \
            --arg sid "$step_id" \
            --arg nid "$new_id" \
            --arg title "$new_title" \
            --arg now "$NOW" \
            '
            .updated_at = $now
            | .plan = [.plan[] |
                ., (if (.id | tostring) == $sid then {id: ($nid|tonumber), title: $title, status: "pending"} else empty end)
              ]
            ' "$FILE" > "$tmp"
        mv "$tmp" "$FILE"
        echo "[state] $phase split: inserted $new_id after $step_id ($new_title)"
        ;;

    note)
        text="${3:-}"
        [ -z "$text" ] && { echo "ERROR: usage: note <phase> <text>" >&2; exit 2; }
        [ ! -f "$FILE" ] && { echo "ERROR: state not found" >&2; exit 1; }
        # 截到 500 字
        trimmed="$(echo "$text" | cut -c1-500)"
        tmp="$(mktemp)"
        jq --arg now "$NOW" --arg note "$trimmed" '.updated_at = $now | .notes = $note' "$FILE" > "$tmp"
        mv "$tmp" "$FILE"
        echo "[state] $phase note updated"
        ;;

    *)
        echo "ERROR: unknown cmd: $cmd" >&2
        exit 2
        ;;
esac
