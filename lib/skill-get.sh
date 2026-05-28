#!/usr/bin/env bash
# skill-get.sh — 取 skill 全文
#
# 用法：bash skill-get.sh <skill_path>   # 如 framework/antd/form
# 输出：skill md 全文 到 stdout

set -e

LOCAL_DIR="$HOME/.claude/quill-skills"
SKILL="${1:?usage: skill-get.sh <skill_path>}"

# 容错：用户可能传入 skills/foo.md 或 foo 或 foo.md
SKILL="${SKILL#skills/}"
SKILL="${SKILL%.md}"

F="$LOCAL_DIR/skills/${SKILL}.md"
[ -f "$F" ] || { echo "ERROR: skill not found: $F" >&2; exit 1; }
cat "$F"
