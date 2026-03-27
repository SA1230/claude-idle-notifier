#!/bin/bash
set -e

SCRIPTS_DIR="$HOME/.claude/scripts"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Uninstalling Claude Code idle notifier..."

# 1. Remove scripts and icons
rm -f "$SCRIPTS_DIR/claude-idle-notify.sh"
rm -f "$SCRIPTS_DIR/claude-idle-kill.sh"
rm -f "$SCRIPTS_DIR/claude-permission-notify.sh"
rm -f "$SCRIPTS_DIR/icons/idle.png"
rm -f "$SCRIPTS_DIR/icons/permission.png"
rm -f "$SCRIPTS_DIR/icons/nudge.png"

# 2. Kill any running nudger
if [ -f /tmp/claude-idle-nudger.pid ]; then
    pid=$(cat /tmp/claude-idle-nudger.pid)
    kill "$pid" 2>/dev/null || true
    pkill -P "$pid" 2>/dev/null || true
    rm -f /tmp/claude-idle-nudger.pid
fi
rm -f /tmp/claude-idle-context.json

# 3. Remove hooks from settings.json
if [ -f "$SETTINGS_FILE" ]; then
    UPDATED=$(cat "$SETTINGS_FILE" | jq '
        .hooks.Stop = [.hooks.Stop[]? | select(.hooks[0].command != "~/.claude/scripts/claude-idle-notify.sh")] |
        .hooks.PermissionRequest = [.hooks.PermissionRequest[]? | select(.hooks[0].command != "~/.claude/scripts/claude-permission-notify.sh")] |
        .hooks.UserPromptSubmit = [.hooks.UserPromptSubmit[]? | select(.hooks[0].command != "~/.claude/scripts/claude-idle-kill.sh")] |
        # Clean up empty arrays
        if .hooks.Stop == [] then del(.hooks.Stop) else . end |
        if .hooks.PermissionRequest == [] then del(.hooks.PermissionRequest) else . end |
        if .hooks.UserPromptSubmit == [] then del(.hooks.UserPromptSubmit) else . end |
        if .hooks == {} then del(.hooks) else . end
    ')
    echo "$UPDATED" | jq '.' > "$SETTINGS_FILE"
    echo "Removed hooks from settings.json"
fi

echo ""
echo "Uninstalled. Note: terminal-notifier and ~/.claude/notify-config.env were left in place."
echo "Restart your Claude Code session to fully deactivate."
