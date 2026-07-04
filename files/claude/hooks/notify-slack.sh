#!/bin/bash
# .claude/hooks/notify-slack.sh
INPUT=$(cat)
STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // "unknown"')

if [ "$STOP_REASON" = "end_turn" ]; then
  curl -s -X POST "$SLACK_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "{\"text\": \"Claude Codeのタスクが完了しました\"}" \
    > /dev/null 2>&1
fi
