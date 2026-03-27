#!/bin/bash
# Kills the idle nudger when Claude starts working again.
# Triggered by the UserPromptSubmit hook.

PID_FILE="/tmp/claude-idle-nudger.pid"

if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    kill "$pid" 2>/dev/null
    pkill -P "$pid" 2>/dev/null
    rm -f "$PID_FILE"
fi
