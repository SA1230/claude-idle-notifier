#!/bin/bash
# Urgent notification when Claude is blocked on a permission prompt.
# Uses dialog popup (always visible) + terminal-notifier (for when away).

STDIN_JSON=$(cat)
ICON="$HOME/.claude/scripts/icons/permission.png"

PROJECT=$(echo "$STDIN_JSON" | jq -r '.cwd // empty' 2>/dev/null | xargs basename 2>/dev/null)
[ -z "$PROJECT" ] && PROJECT="Claude Code"

TOOL=$(echo "$STDIN_JSON" | jq -r '.tool_name // "a tool"' 2>/dev/null)

# Extract a short preview of what's being requested
DETAIL=""
if [ "$TOOL" = "Bash" ]; then
    DETAIL=$(echo "$STDIN_JSON" | jq -r '.tool_input.command // empty' 2>/dev/null | head -c 60)
elif [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; then
    DETAIL=$(echo "$STDIN_JSON" | jq -r '.tool_input.file_path // empty' 2>/dev/null | xargs basename 2>/dev/null)
fi

if [ -n "$DETAIL" ]; then
    BODY="Approve $TOOL: $DETAIL"
else
    BODY="Approve $TOOL to continue"
fi

# Urgent sound
afplay /System/Library/Sounds/Funk.aiff 2>/dev/null &

# Dialog popup — always shows even when terminal is focused, auto-dismisses after 10s
osascript -e "display dialog \"$BODY\" with title \"$PROJECT — Action Required\" buttons {\"OK\"} giving up after 10" 2>/dev/null &

# Also send notification banner for when user is away from terminal
terminal-notifier \
    -title "$PROJECT — Action Required" \
    -message "$BODY" \
    -contentImage "$ICON" \
    -sound "" \
    -sender com.apple.Finder \
    -group "claude-permission" \
    2>/dev/null &
