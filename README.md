# Tempo

A native macOS time tracking app built with SwiftUI that uses the [Noko](https://nokotime.com) API v2 as its backend. Designed to feel like a first-party Apple app — warm, precise, and unobtrusive.

## Features

- **Timer Dashboard** — Live timer display with start, pause, and stop controls. Quick-start bar with project picker and default project fallback.
- **Entries Log** — Chronological list grouped by day with search, filtering, inline editing, and delete with undo.
- **Reports** — Weekly/monthly stacked bar chart with summary cards and project breakdown.
- **Infinite Calendar** — Continuously scrolling 7-column grid with month banners, per-day entry summaries, and windowed data loading.
- **Projects** — Read-only card grid showing project colors, names, and per-project hour stats.
- **Menu Bar Widget** — Always-visible timer in the macOS menu bar with quick controls and recent tasks.

## Requirements

- macOS 14 (Sonoma) or later
- A [Noko](https://nokotime.com) account with a personal access token

## Getting Started

1. Clone the repo and open `Tempo.xcodeproj` in Xcode.
2. Build and run.
3. On first launch, Tempo will ask for your Noko personal access token. You can generate one from your Noko account settings.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘N` | New entry / focus quick start |
| `⌘S` | Start/stop timer |
| `⌘P` | Pause timer |
| `⌘1–5` | Switch views |
| `⌘T` | Jump to today (calendar) |
| `⌘,` | Preferences |

## License

[0BSD](LICENSE) — Copyright 2026 Martin Johannesson
