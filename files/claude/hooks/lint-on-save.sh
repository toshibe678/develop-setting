#!/bin/bash
# .claude/hooks/lint-on-save.sh
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_result.filePath // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# TypeScriptファイルのみリント
if [[ "$FILE_PATH" == *.ts || "$FILE_PATH" == *.tsx ]]; then
  RESULT=$(npx eslint --fix "$FILE_PATH" 2>&1)
  if [ $? -ne 0 ]; then
    jq -n --arg msg "$RESULT" '{
      hookSpecificOutput: {
        hookEventName: "PostToolUse"
      },
      transcript: ("ESLintエラー:\n" + $msg)
    }'
  fi
fi

exit 0
