# Tempo — macOS Time Reporting App

## Overview

A native macOS time tracking app built with SwiftUI that uses the Noko (nokotime) API v2 as its backend. Single-user personal client — one Noko account, one token. Designed to feel like a first-party Apple app — warm, precise, and unobtrusive.

## Tech Stack

- **UI Framework:** SwiftUI (macOS 14+ / Sonoma)
- **Language:** Swift
- **Backend:** Noko API v2 (`https://api.nokotime.com/v2`)
- **Architecture:** MVVM with async/await
- **Persistence:** Local cache with UserDefaults for cached projects/tags/entries
- **Distribution:** Direct download / TestFlight (not Mac App Store initially)
- **Connectivity:** Online-only. Show an offline indicator and disable actions when connectivity is lost. No offline queue or local-first sync.

## Core Views

### 1. Timer Dashboard (Main View)
- Active timer display with elapsed time, project tag, and task description
- **Paused timer indicator:** If paused timers exist, show a collapsed "N paused" badge that expands to a list on click, allowing the user to resume any of them
- Quick-start bar: text field + project picker + start button
  - If no project is selected, falls back to the user's **default project** configured in Preferences
  - Start button is disabled if no project is selected AND no default project is set
- Today's entries list with duration, time range, and project color
- Summary stats strip: **today's total, this week total, this month total, entry count** (all derived from Noko data, no locally-computed metrics)

### 2. Entries Log
- Chronological list grouped by day with sticky day headers
- Search bar + filter pills (project, date range)
  - **Search strategy:** Filter locally over loaded entries first. If local results are insufficient, show a "Search all entries" button that queries Noko's server-side `description` filter
- Each row: color bar, task title, project tag, time range, duration
- Hover actions:
  - **Resume:** Start a new timer with the same description and project, always using today's date (one-click, no date prompt)
  - **Edit:** Inline or popover edit of description, project, and duration
  - **Delete:** Delete from Noko immediately, show a brief "Undo" toast that re-creates the entry if clicked within ~5 seconds
- Pagination footer
- Billable status is **not surfaced** — irrelevant for this use case

### 3. Weekly/Monthly Report
- Stacked bar chart (7 columns for week, toggleable to monthly)
- Summary cards: total hours, daily average, top project, entry count
- Project breakdown with horizontal progress bars and percentages

### 4. Infinite Calendar
- 7-column grid scrolling continuously through time (no month picker)
- Inline month banners as sticky headers with total hours
- Each cell: date, total hours badge, compact entry rows (color dot + name + duration)
- "+N more" overflow for busy days
- Floating "Today" pill to jump back to current date
- Auto-scrolls to today on open
- **Data loading:** Initial window is ±3 months around today. Fetch the next month of entries on demand as the user scrolls toward either edge. No hard limit — keeps loading as long as the user scrolls, one month at a time.

### 5. Projects
- Card grid (2 columns) with project color, name, description
- Per-project stats: this week and this month hours
- **No budget tracking** — Noko doesn't have a budget field, and maintaining it locally isn't worth the complexity
- **No project creation** — projects are managed in Noko's web UI. The "New Project" button is replaced with an "Open in Noko" link that opens the Noko projects page in the browser
- Projects list is read-only and refreshed on app launch

### 6. Menu Bar Widget
- Always-visible menu bar item showing running timer duration
- Popover: current timer, today's total, recent tasks for quick restart
- Start/pause/stop controls (same behavior as main window)
- "Open Tempo" link to bring main window forward

## Timer Behavior

### Starting a Timer
- Noko only allows **one running timer at a time**. Starting a new timer automatically pauses any currently running timer (Noko handles this server-side).
- Quick-start requires a project. If none selected, uses the default project from Preferences.

### Pausing
- Pause button (❚❚) pauses the running timer via Noko API. Timer stays alive and can be resumed.

### Stopping (Logging)
- Stop button (■) triggers a **confirmation popover** showing:
  - Task description (editable)
  - Project (shown, not editable here)
  - Duration in hours (editable, pre-filled from timer seconds → rounded to nearest 0.5h)
  - "Log Entry" confirm button + "Cancel" to go back to running/paused
- On confirm: calls Noko's `log` endpoint which creates an entry and discards the timer.

### Timer Display
- Local timer ticks every second for display purposes.
- Timer state is polled from Noko every 30 seconds when the main window is not focused, to stay in sync if the user changes things in Noko's web UI.

## Time Input

- Duration fields (create/edit entry, log timer confirmation) accept **free-text input** supporting:
  - Decimal hours: `1.5` → 90 minutes
  - Hours and minutes: `1:30` → 90 minutes
- Noko auto-rounds to the project's `billing_increment` server-side; Tempo does not enforce increments in the UI.
- Display format throughout the app: hours and minutes (e.g., "1:30" not "90m").

## Noko API v2 Integration

### Authentication
- Personal access token stored in Keychain
- Sent via `X-NokoToken` header on every request
- `User-Agent: Tempo/1.0` header required

### Onboarding
- On first launch (or if token is missing/invalid), show a **modal setup screen** that:
  - Explains what Tempo needs
  - Links to Noko's personal access token page
  - Has a text field to paste the token
  - Validates the token by calling `GET /v2/current_user`
  - Blocks access to the main app until a valid token is configured

### API Client (`NokoClient`)

```swift
actor NokoClient {
    let baseURL = URL(string: "https://api.nokotime.com/v2")!
    let token: String

    func entries(from: Date?, to: Date?, projectIds: [Int]?) async throws -> [Entry]
    func createEntry(date: Date, minutes: Int, projectId: Int?, description: String?) async throws -> Entry
    func updateEntry(id: Int, ...) async throws -> Entry
    func deleteEntry(id: Int) async throws

    func projects() async throws -> [Project]
    func timers() async throws -> [NokoTimer]
    func startTimer(projectId: Int, description: String?) async throws -> NokoTimer
    func pauseTimer(projectId: Int) async throws -> NokoTimer
    func logTimer(projectId: Int, description: String?, minutes: Int?) async throws -> Entry

    func currentUser() async throws -> User
    func tags() async throws -> [Tag]
}
```

### Data Models

```swift
struct Entry: Codable, Identifiable {
    let id: Int
    let date: String              // "YYYY-MM-DD"
    let minutes: Int
    let description: String?
    let project: ProjectRef?
    let tags: [TagRef]
    let user: UserRef
    let createdAt: String
    let updatedAt: String
}

struct Project: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String             // hex like "#ff9898"
    let billingIncrement: Int
    let enabled: Bool
    let billable: Bool
}

struct NokoTimer: Codable, Identifiable {
    let id: Int
    let state: String             // "running", "paused"
    let seconds: Int
    let formattedTime: String
    let date: String
    let description: String?
    let project: ProjectRef
}
```

### Pagination Strategy
- Fetch with `per_page=1000` for projects/tags (small datasets)
- Entries: paginate with `per_page=100`, follow `Link` header for next pages
- Calendar view: fetch entries in 1-month date ranges as user scrolls (windowed loading)

### Rate Limiting
- 2 requests/second limit
- Queue requests with throttling in `NokoClient`
- Retry on 429 with exponential backoff (max 3 retries)

### Caching
- Cache projects and tags locally (refresh on app launch)
- Cache entries by date range (invalidate on create/update/delete)
- Timer state polled every 30s when app is backgrounded, live tick when foregrounded

## App Architecture

```
Tempo/
├── App/
│   ├── TempoApp.swift              # @main, WindowGroup + MenuBarExtra
│   ├── AppState.swift              # @Observable shared state
│   └── OnboardingView.swift        # Modal token setup
├── API/
│   ├── NokoClient.swift            # API client (actor)
│   ├── Models.swift                # Codable data models
│   └── Pagination.swift            # Link header parser
├── ViewModels/
│   ├── TimerViewModel.swift
│   ├── EntriesViewModel.swift
│   ├── ReportViewModel.swift
│   ├── CalendarViewModel.swift
│   └── ProjectsViewModel.swift
├── Views/
│   ├── Sidebar.swift               # Navigation sidebar
│   ├── Timer/
│   │   ├── TimerDashboard.swift
│   │   ├── ActiveTimerCard.swift
│   │   ├── PausedTimersIndicator.swift
│   │   ├── QuickStartBar.swift
│   │   ├── LogTimerPopover.swift   # Stop confirmation
│   │   └── TodayEntriesList.swift
│   ├── Entries/
│   │   ├── EntriesView.swift
│   │   ├── EntryRow.swift
│   │   ├── EntriesToolbar.swift
│   │   └── UndoToast.swift
│   ├── Reports/
│   │   ├── ReportView.swift
│   │   ├── BarChart.swift
│   │   └── ProjectBreakdown.swift
│   ├── Calendar/
│   │   ├── CalendarView.swift
│   │   ├── CalendarGrid.swift
│   │   ├── CalendarCell.swift
│   │   └── MonthBanner.swift
│   ├── Projects/
│   │   ├── ProjectsView.swift
│   │   └── ProjectCard.swift
│   └── MenuBar/
│       └── MenuBarPopover.swift
├── Utilities/
│   ├── KeychainHelper.swift
│   ├── TimeFormatter.swift         # Parses "1.5" and "1:30" → minutes
│   └── ColorExtensions.swift       # Hex string → SwiftUI Color
└── Resources/
    └── Assets.xcassets
```

## Design Tokens (from Exploration II — "Tempo")

### Colors
| Token | Light | Dark |
|-------|-------|------|
| Background | `#f0f2f5` | `#0c0e14` |
| Window | `#ffffff` | `#12141c` |
| Sidebar | `#f7f8fa` | `#0f1119` |
| Text Primary | `#111827` | `#e8eaf0` |
| Text Secondary | `#6b7280` | `#8b90a0` |
| Accent | `#3b82f6` | `#3b82f6` |
| Accent Secondary | `#8b5cf6` | `#8b5cf6` |

### Project Colors (from Noko hex values)
Map Noko's `project.color` hex string directly to SwiftUI `Color(hex:)`.

### Typography
- **Primary:** System font (SF Pro via `.body`, `.title`, etc.)
- **Monospace:** `.monospacedDigit()` for timers and durations
- Use SF Symbols for all icons

## Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `⌘N` | New entry / quick start focus |
| `⌘S` | Start/stop timer |
| `⌘P` | Pause timer |
| `⌘1–5` | Switch views |
| `⌘T` | Jump to today (calendar) |
| `⌘,` | Preferences |

## Settings / Preferences
- Noko API token (stored in Keychain, editable with re-validation)
- Default project for new timers (dropdown of active projects)
- Show/hide menu bar widget
- Launch at login
- Notification when timer exceeds N hours (configurable threshold)

## Implementation Phases

### Phase 1 — Foundation
- [ ] Xcode project setup, SwiftUI app lifecycle with `MenuBarExtra`
- [ ] `NokoClient` with auth, entries, projects, timers endpoints
- [ ] Keychain token storage + modal onboarding screen with token validation
- [ ] Core data models
- [ ] Rate limiter / request throttle in API client

### Phase 2 — Timer + Entries
- [ ] Timer dashboard with live timer display
- [ ] Start/pause timer via Noko API
- [ ] Stop → log confirmation popover with editable description and duration
- [ ] Paused timers collapsed indicator
- [ ] Quick-start bar with default project fallback
- [ ] Entries list view with day grouping
- [ ] Create/edit entries with flexible time input (decimal hours and h:mm)
- [ ] Delete with undo toast

### Phase 3 — Reports + Calendar
- [ ] Weekly bar chart with project breakdown
- [ ] Summary stat cards (from Noko data only)
- [ ] Infinite scrolling calendar grid with ±3 month initial window
- [ ] Windowed date-range fetching (1 month at a time on scroll)
- [ ] Month banners and today floating pill

### Phase 4 — Polish
- [ ] Menu bar widget popover
- [ ] Keyboard shortcuts
- [ ] Local caching for projects/tags/entries
- [ ] Settings/preferences window with default project picker
- [ ] Light/dark theme matching system appearance
- [ ] Offline indicator (disable actions when no connectivity)
