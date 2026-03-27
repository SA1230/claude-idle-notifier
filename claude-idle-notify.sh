#!/bin/bash
# Claude Code idle notification system
# Triggered by the Stop hook when Claude finishes its turn.
# Uses terminal-notifier with distinct icons per notification tier.

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

# Grace period — filters out rapid back-and-forth during active conversation
sleep 8

# First notification — green checkmark icon
afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
terminal-notifier \
    -title "$PROJECT" \
    -message "$SNIPPET" \
    -contentImage "$ICON_IDLE" \
    -sound "" \
    -group "claude-idle" \
    2>/dev/null

ELAPSED=8
TELEGRAM_INTERVAL=600
LAST_TELEGRAM=0

while true; do
    sleep 90
    ELAPSED=$((ELAPSED + 90))
    MINUTES=$((ELAPSED / 60))

    # Repeated nudge — amber clock icon
    afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
    terminal-notifier \
        -title "$PROJECT" \
        -message "Still waiting... (${MINUTES}m idle)" \
        -contentImage "$ICON_NUDGE" \
        -sound "" \
        -group "claude-idle" \
        2>/dev/null

    # Telegram escalation: first at 5 min, then every 10 min
    if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
        if [ $ELAPSED -ge 300 ]; then
            SINCE_LAST=$((ELAPSED - LAST_TELEGRAM))
            if [ $LAST_TELEGRAM -eq 0 ] || [ $SINCE_LAST -ge $TELEGRAM_INTERVAL ]; then
                curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                    -d chat_id="$TELEGRAM_CHAT_ID" \
                    -d text="[$PROJECT] ${SNIPPET}... (${MINUTES}m idle)" \
                    > /dev/null 2>&1
                LAST_TELEGRAM=$ELAPSED
            fi
        fi
    fi
done
' > /dev/null 2>&1 &

# Save the nudger PID so the kill script can stop it
echo $! > "$PID_FILE"
