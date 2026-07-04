#!/bin/bash
# .claude/hooks/block-secrets.sh
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# 秘密情報を含むコマンドをブロック
if echo "$COMMAND" | grep -qE '(password|secret|token|api.?key)'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "秘密情報を含む可能性のあるコマンドがブロックされました"
    }
  }'
  exit 0
fi

# rm -rf をブロック
if echo "$COMMAND" | grep -qE 'rm\s+-rf'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "rm -rf は禁止されています"
    }
  }'
  exit 0
fi

exit 0
