#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$HOME/.claude/scripts"
ICONS_DIR="$SCRIPTS_DIR/icons"
SETTINGS_FILE="$HOME/.claude/settings.json"
CONFIG_FILE="$HOME/.claude/notify-config.env"

echo "Installing Claude Code idle notifier..."

# 1. Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This tool only works on macOS (requires macOS notifications and afplay)."
    exit 1
fi

# 2. Install terminal-notifier if missing
if ! command -v terminal-notifier &>/dev/null; then
    if command -v brew &>/dev/null; then
        echo "Installing terminal-notifier via Homebrew..."
        brew install terminal-notifier
    else
        echo "Error: terminal-notifier is required. Install Homebrew (https://brew.sh) then run:"
        echo "  brew install terminal-notifier"
        exit 1
    fi
fi

# 3. Check for jq
if ! command -v jq &>/dev/null; then
    if command -v brew &>/dev/null; then
        echo "Installing jq via Homebrew..."
        brew install jq
    else
        echo "Error: jq is required. Install via: brew install jq"
        exit 1
    fi
fi

# 4. Copy scripts and icons
echo "Copying scripts to $SCRIPTS_DIR..."
mkdir -p "$ICONS_DIR"
cp "$REPO_DIR/claude-idle-notify.sh" "$SCRIPTS_DIR/"
cp "$REPO_DIR/claude-idle-kill.sh" "$SCRIPTS_DIR/"
cp "$REPO_DIR/claude-permission-notify.sh" "$SCRIPTS_DIR/"
cp "$REPO_DIR/icons/"*.png "$ICONS_DIR/"
chmod +x "$SCRIPTS_DIR/claude-idle-notify.sh" "$SCRIPTS_DIR/claude-idle-kill.sh" "$SCRIPTS_DIR/claude-permission-notify.sh"

# 5. Create config template if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    cp "$REPO_DIR/notify-config.env" "$CONFIG_FILE"
    echo "Created Telegram config template at $CONFIG_FILE"
fi

# 6. Merge hooks into settings.json
echo "Configuring hooks in $SETTINGS_FILE..."

# Create settings.json if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
fi

# Define the hooks to add
STOP_HOOK='{
    "hooks": [
        {
            "type": "command",
            "command": "~/.claude/scripts/claude-idle-notify.sh",
            "timeout": 5,
            "async": true
        }
    ]
}'

PERMISSION_HOOK='{
    "hooks": [
        {
            "type": "command",
            "command": "~/.claude/scripts/claude-permission-notify.sh",
            "timeout": 5,
            "async": true
        }
    ]
}'

KILL_HOOK='{
    "hooks": [
        {
            "type": "command",
            "command": "~/.claude/scripts/claude-idle-kill.sh",
            "timeout": 3
        }
    ]
}'

# Check if hooks already exist (idempotent)
EXISTING=$(cat "$SETTINGS_FILE")

add_hook() {
    local event="$1"
    local hook_json="$2"
    local script_path="$3"

    # Check if this hook is already configured
    if echo "$EXISTING" | jq -e ".hooks.${event}[]? | select(.hooks[]?.command == \"${script_path}\")" &>/dev/null; then
        echo "  $event hook already configured, skipping."
        return
    fi

    # Add hook to the event array (create array if it doesn't exist)
    EXISTING=$(echo "$EXISTING" | jq ".hooks.${event} = (.hooks.${event} // []) + [${hook_json}]")
}

add_hook "Stop" "$STOP_HOOK" "~/.claude/scripts/claude-idle-notify.sh"
add_hook "PermissionRequest" "$PERMISSION_HOOK" "~/.claude/scripts/claude-permission-notify.sh"
add_hook "UserPromptSubmit" "$KILL_HOOK" "~/.claude/scripts/claude-idle-kill.sh"

# Write back
echo "$EXISTING" | jq '.' > "$SETTINGS_FILE"

echo ""
echo "Done! Claude Code idle notifier is installed."
echo ""
echo "What you'll get:"
echo "  🟢 Glass chime + notification when Claude finishes (after 8s grace period)"
echo "  🔴 Funk alert + notification when Claude needs permission approval"
echo "  🟠 Ping + notification every 90s while Claude is still waiting"
echo "  📱 Telegram message after 5 min idle (configure in ~/.claude/notify-config.env)"
echo ""
echo "Open /hooks in Claude Code or restart your session to activate."
