# Claude Code Idle Notifier

Never miss when Claude Code is waiting for you. Get escalating notifications — sound, desktop alert, and optionally Telegram — when Claude finishes, needs permission, or has been idle too long.

## Notification Tiers

| Situation | Icon | Sound | When |
|---|---|---|---|
| **Claude finished** | 🟢 Green checkmark | Glass | 8s after Claude stops |
| **Permission needed** | 🔴 Red exclamation | Funk | Immediately when approval needed |
| **Still waiting** | 🟠 Amber clock | Ping | Every 90s while idle |
| **Telegram escalation** | — | — | After 5m idle, then every 10m |

## Install

```bash
git clone https://github.com/shiroy/claude-idle-notifier.git
cd claude-idle-notifier
bash install.sh
```

Then restart your Claude Code session (or open `/hooks` to reload).

### Requirements

- macOS (uses native notifications and `afplay`)
- [Homebrew](https://brew.sh) (for installing dependencies)
- `terminal-notifier` and `jq` (installed automatically by the script)

## Telegram Setup (Optional)

For mobile notifications when Claude has been idle 5+ minutes:

1. Message [@BotFather](https://t.me/BotFather) on Telegram, send `/newbot`, follow the prompts
2. Copy the bot token
3. Message your new bot, then visit `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates` to find your `chat_id`
4. Edit `~/.claude/notify-config.env`:

```bash
TELEGRAM_BOT_TOKEN="123456:ABC-DEF..."
TELEGRAM_CHAT_ID="your_chat_id"
```

## How It Works

Three [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) power the system:

- **`Stop` hook** → When Claude finishes its turn, waits 8 seconds (grace period to filter active conversation), then plays a sound and shows a macOS notification with a preview of Claude's last message. Spawns a background process that re-notifies every 90 seconds.
- **`PermissionRequest` hook** → When Claude needs approval to run a tool (Bash, Write, Edit, etc.), immediately plays an urgent sound and shows a notification with what's being requested.
- **`UserPromptSubmit` hook** → When you type anything, kills the background nudger so notifications stop.

## Uninstall

```bash
cd claude-idle-notifier
bash uninstall.sh
```

## Files

```
~/.claude/scripts/
├── claude-idle-notify.sh        # Stop hook: sound + notification + background nudger
├── claude-idle-kill.sh          # UserPromptSubmit hook: kills the nudger
├── claude-permission-notify.sh  # PermissionRequest hook: urgent notification
└── icons/
    ├── idle.png                 # Green checkmark
    ├── permission.png           # Red exclamation
    └── nudge.png                # Amber clock

~/.claude/notify-config.env      # Telegram bot credentials (optional)
```
