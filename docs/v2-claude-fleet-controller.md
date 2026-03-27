# Claude Fleet Controller — Design Doc

## Vision

A persistent macOS desktop widget that monitors all active Claude Code sessions and acts as an intelligent air traffic controller for your Claude fleet. Always visible, always aware, always contextual.

## The Problem

When running multiple Claude Code sessions simultaneously, you lose track of which sessions need attention. You tab between terminals, miss permission prompts, forget sessions that finished 20 minutes ago. The v1 notification system (sound + popup + Telegram) helps for single sessions but doesn't scale — 4 sessions screaming equally is just noise.

## The Solution

A floating glass panel that lives on your desktop showing:

1. **Ambient session orbs** — each active session as a glowing orb. Color = status, size = urgency (grows the longer it waits). You glance at it like a clock.
2. **Contextual nudges** — an LLM reads actual conversation context and tells you what matters in plain English, not just "session X is idle."
3. **Return-from-away digest** — when you've been gone, a one-paragraph briefing of what happened across all sessions.

## User Experience

### Always-Visible Widget
- Floating transparent panel, always on top, in a screen corner (draggable)
- Minimal footprint: ~200x300px default, expandable on hover/click
- Dark glass aesthetic matching Alfred's design language

### Session Orbs
| State | Color | Animation | Size |
|-------|-------|-----------|------|
| Working | Green | Gentle pulse | Small |
| Waiting for user | Amber | Slow breathe | Grows over time |
| Permission blocked | Red | Fast pulse | Large immediately |
| Completed | Blue | Fade out | Small |

### Intelligent Nudges
The LLM doesn't just report status — it prioritizes and contextualizes:

```
"The AI Intel pipeline design needs your input on two blockers
before Claude can write the implementation plan. This is the
most time-sensitive of your 4 active sessions."
```

```
"You've been away 45 minutes. Here's what happened:
- alfred/notifications: shipped and pushed to GitHub ✓
- alfred/interactive-cards: waiting for design approval (12m)
- dreamboard/auth: still running tests
Quick win: approve the interactive-cards design first."
```

### Timeline View (expanded)
Click the widget to expand into a timeline showing cross-session activity:
- What completed while you were away
- What's blocked and why
- Suggested priority order for catching up

## Architecture

### Data Sources
- **JSONL transcripts** in `~/.claude/projects/*/` — tail these for real-time session state
- **Stop hook payloads** — `last_assistant_message`, `session_id`, `cwd`, `stop_hook_active`
- **PID files** in `/tmp/` — detect which sessions are alive
- **Process table** — `pgrep -f "claude"` to find active Claude Code processes

### Components

```
┌─────────────────────────────────────────┐
│           Fleet Controller UI           │
│  (Tauri: Rust backend + Web frontend)   │
├─────────────────────────────────────────┤
│              Session Monitor            │
│  - Tails JSONL transcripts              │
│  - Watches Stop hook context files      │
│  - Tracks session lifecycle             │
├─────────────────────────────────────────┤
│           Intelligence Layer            │
│  - Claude Haiku for summarization       │
│  - Priority scoring across sessions     │
│  - Digest generation on return          │
├─────────────────────────────────────────┤
│            Notification Bus             │
│  - Desktop nudges (dialog + banner)     │
│  - Widget state updates                 │
│  - Telegram escalation                  │
└─────────────────────────────────────────┘
```

### Tech Stack
- **Tauri** — Rust + web UI for native macOS menubar/widget. Tiny footprint (~5MB), no Electron bloat
- **Frontend** — Solid.js or Svelte for reactive UI (lightweight, fast)
- **LLM** — Claude Haiku via Anthropic API for summarization/nudges (~$0.01/call, called every 30-60s)
- **File watching** — `notify` crate (Rust) or `fswatch` for transcript tailing
- **IPC** — Tauri commands between Rust backend and web frontend

### Why Tauri over Electron
- 50x smaller binary (~5MB vs ~250MB)
- Native macOS window management (always-on-top, transparency, click-through)
- Rust backend = efficient file watching and process monitoring
- Lower memory footprint for something that runs 24/7

### Session Detection
```
1. Scan ~/.claude/projects/ for recently modified .jsonl files
2. For each transcript, check if a Claude Code process is still running
3. Parse the last few entries to determine state:
   - Last entry is assistant message → waiting for user
   - Last entry is tool_use → working
   - Permission prompt in last entry → blocked
   - No updates in 5+ min with live process → stalled
4. Feed state + last_assistant_message to Haiku for summarization
```

### Intelligence Layer Protocol
Every 30 seconds, if any session state changed:
```
Prompt to Haiku:
"You are monitoring {N} Claude Code sessions for a developer.
Summarize what needs attention, prioritized by urgency.

Session 1 ({project}): {status}, idle {duration}
Last message: {truncated last_assistant_message}

Session 2 ({project}): {status}, idle {duration}
Last message: {truncated last_assistant_message}

Generate a 1-2 sentence nudge for the most urgent item.
If nothing needs attention, respond with NONE."
```

Cost estimate: ~720 Haiku calls/day × $0.01 = ~$7/day. Could optimize with change detection to only call when state changes.

### Return-from-Away Detection
- Track last user interaction timestamp (any `UserPromptSubmit` across sessions)
- If gap > 10 minutes, trigger a digest on next interaction
- Digest summarizes everything that happened during the gap

## Phased Build Plan

### Phase 1: Session Monitor (MVP)
- Tauri menubar app with dropdown
- List all active sessions with status (working/waiting/blocked)
- Project name + one-line summary from last message
- Click to open terminal tab (via `osascript`)
- Replace v1 notification scripts — the widget IS the notification

### Phase 2: Ambient Orbs
- Floating widget with session orbs
- Color/size/animation based on state
- Hover for details, click to focus session
- Always-on-top with transparency

### Phase 3: Intelligence
- Haiku integration for contextual nudges
- Priority scoring across sessions
- "Most urgent" callout in the widget

### Phase 4: Digest & Timeline
- Return-from-away detection
- Cross-session activity timeline
- "Here's what happened" briefing
- Historical session summaries

## Open Questions

1. **Widget framework** — Tauri supports floating windows but macOS transparency/click-through behavior needs testing. Alternative: SwiftUI native app with embedded web view for the orb animations.
2. **Session identity** — Claude Code sessions don't have user-friendly names. Use project directory basename? Allow manual naming?
3. **Multi-machine** — If running sessions on a remote server too, how to aggregate? WebSocket relay?
4. **Standalone product potential** — This is useful for anyone running multiple Claude Code sessions. Worth packaging as an open-source tool?
