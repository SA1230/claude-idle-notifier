#!/bin/bash
# Claude Code idle notification system
# Triggered by the Stop hook when Claude finishes its turn.
# Uses dialog popup (always visible) + terminal-notifier (for when away).

PID_FILE="/tmp/claude-idle-nudger.pid"
CONFIG_FILE="$HOME/.claude/notify-config.env"
CONTEXT_FILE="/tmp/claude-idle-context.json"
ICON_IDLE="$HOME/.claude/scripts/icons/idle.png"
ICON_NUDGE="$HOME/.claude/scripts/icons/nudge.png"

# Kill any existing nudger first
if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE")
    kill "$old_pid" 2>/dev/null
    pkill -P "$old_pid" 2>/dev/null
    rm -f "$PID_FILE"
fi

# Read stdin payload and extract session context
STDIN_JSON=$(cat)

# Extract project name from cwd
PROJECT=$(echo "$STDIN_JSON" | jq -r '.cwd // empty' 2>/dev/null | xargs basename 2>/dev/null)
[ -z "$PROJECT" ] && PROJECT="Claude Code"

# Extract first 80 chars of last message as a preview snippet
SNIPPET=$(echo "$STDIN_JSON" | jq -r '.last_assistant_message // empty' 2>/dev/null \
    | tr '\n' ' ' \
    | sed 's/[*#`>_~\[\]]//g' \
    | sed 's/  */ /g' \
    | head -c 80)
[ -z "$SNIPPET" ] && SNIPPET="Finished and waiting for you"

# Save context for the nudger
jq -n --arg project "$PROJECT" --arg snippet "$SNIPPET" \
    --arg icon_idle "$ICON_IDLE" --arg icon_nudge "$ICON_NUDGE" \
    '{"project":$project,"snippet":$snippet,"icon_idle":$icon_idle,"icon_nudge":$icon_nudge}' > "$CONTEXT_FILE"

# Load Telegram config if available
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Launch the nudger in the background
nohup bash -c '
PID_FILE="/tmp/claude-idle-nudger.pid"
CONFIG_FILE="$HOME/.claude/notify-config.env"
CONTEXT_FILE="/tmp/claude-idle-context.json"
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

PROJECT="Claude Code"
SNIPPET="Finished and waiting for you"
ICON_IDLE="$HOME/.claude/scripts/icons/idle.png"
ICON_NUDGE="$HOME/.claude/scripts/icons/nudge.png"
if [ -f "$CONTEXT_FILE" ]; then
    PROJECT=$(jq -r ".project" "$CONTEXT_FILE" 2>/dev/null)
    SNIPPET=$(jq -r ".snippet" "$CONTEXT_FILE" 2>/dev/null)
    ICON_IDLE=$(jq -r ".icon_idle" "$CONTEXT_FILE" 2>/dev/null)
    ICON_NUDGE=$(jq -r ".icon_nudge" "$CONTEXT_FILE" 2>/dev/null)
fi

# Hard limit: max 2 reminders per session, then stop
MAX_REMINDERS=2
REMINDER_COUNT=0

# Grace period — filters out rapid back-and-forth during active conversation
sleep 8

# Reminder 1 — dialog popup + notification banner
REMINDER_COUNT=$((REMINDER_COUNT + 1))
afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
osascript -e "display dialog \"$SNIPPET\" with title \"$PROJECT\" buttons {\"OK\"} giving up after 10" 2>/dev/null &
terminal-notifier \
    -title "$PROJECT" \
    -message "$SNIPPET" \
    -contentImage "$ICON_IDLE" \
    -sound "" \
    -sender com.apple.Finder \
    -group "claude-idle" \
    2>/dev/null &

if [ $REMINDER_COUNT -ge $MAX_REMINDERS ]; then
    rm -f "$PID_FILE"
    exit 0
fi

# Wait 90 seconds for one follow-up
sleep 90

# Reminder 2 — final nudge, then stop
REMINDER_COUNT=$((REMINDER_COUNT + 1))
afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
osascript -e "display dialog \"Still waiting... (1m idle)\" with title \"$PROJECT\" buttons {\"OK\"} giving up after 10" 2>/dev/null &
terminal-notifier \
    -title "$PROJECT" \
    -message "Still waiting... (1m idle)" \
    -contentImage "$ICON_NUDGE" \
    -sound "" \
    -sender com.apple.Finder \
    -group "claude-idle" \
    2>/dev/null &

# Done. No more reminders. Clean up.
rm -f "$PID_FILE"
' > /dev/null 2>&1 &

# Save the nudger PID so the kill script can stop it
echo $! > "$PID_FILE"
