# MimirTool UI — Design Spec

**Date:** 2026-04-17  
**Status:** Approved

---

## Overview

A native macOS desktop app that provides a clean GUI for the `mimirtool` CLI. Users manage multiple Mimir environments, view and edit rules/alertmanager config/alerts/remote-read results, and push changes back to Mimir — all without dropping to the terminal.

---

## Tech Stack

- **Language/Framework:** Swift + SwiftUI (macOS 13+)
- **Architecture:** Shell out to `mimirtool` binary via `Process` for all Mimir operations
- **Persistence:** `UserDefaults` + JSON file in `~/Library/Application Support/MimirTool/` for environments and settings
- **No network calls from the app directly** — all Mimir API communication goes through `mimirtool`

---

## Architecture

### Core Layers

```
UI (SwiftUI Views)
    ↓
ViewModel (ObservableObject per view)
    ↓
MimirtoolRunner (Process executor — wraps shell invocations)
    ↓
mimirtool binary (auto-detected or user-specified path)
    ↓
Mimir HTTP API
```

### MimirtoolRunner

Single service responsible for:
- Locating the binary (auto-detect: `/usr/local/bin`, `/opt/homebrew/bin`, `~/.local/bin`, PATH; fallback to user-specified path)
- Building argument arrays for each command
- Injecting per-environment flags (`--address`, `--id` / `--header`, TLS flags, `--log.level`)
- Executing via `Process`, capturing stdout/stderr
- Returning typed results or propagating errors to the ViewModel

### EnvironmentStore

Manages the list of saved environments. Persisted as JSON. Each environment holds:
- `name: String`
- `url: String`
- `orgID: String?` (maps to `--id` / `X-Scope-OrgID` header)
- `extraHeaders: [String: String]`
- `tlsSkipVerify: Bool`
- `caCertPath: String?`
- `timeout: String` (e.g. `"30s"`)
- `retries: Int`

### AppSettings

Global settings persisted separately:
- `mimirtoolPath: String?` (nil = auto-detect)
- `logLevel: String` (info / debug / warn / error)
- `verboseOutput: Bool`

---

## Pages

### 1. Rules

**Purpose:** Browse, upload, edit, and delete Prometheus recording and alerting rules organised by namespace and group.

**mimirtool commands used:**
- List: `mimirtool rules list --output-dir <tmpdir>`
- Push: `mimirtool rules load <file>`
- Delete namespace: `mimirtool rules delete <namespace>`
- Delete group: `mimirtool rules delete <namespace> <group>`

**UI:**
- Toolbar: Refresh icon, search pill, "Upload YAML" button, "+ New Rule" button
- Table: Namespace (tag), Group, Rule Name, Type (alerting/recording), Actions (Edit ✏ / Delete ✕)
- Edit action: opens a sheet with a YAML text editor pre-populated with the rule; on save, writes to a temp file and calls `rules load`
- Upload action: file picker (`.yaml`, `.yml`), calls `rules load`
- Delete: confirmation dialog before calling `rules delete`
- Footer: connected status dot, rule count, namespace count

### 2. Alertmanager

**Purpose:** View, edit, upload, and delete the Alertmanager configuration for the active environment.

**mimirtool commands used:**
- Get: `mimirtool alertmanager get`
- Push: `mimirtool alertmanager load <file>`
- Delete: `mimirtool alertmanager delete`

**UI:**
- Split layout: YAML editor (left, ~65% width) + Config Summary panel (right, ~35%)
- Editor: syntax-highlighted YAML using `NSTextView` wrapped in SwiftUI; tracks unsaved changes
- Config Summary panel: parsed read-only view showing global settings, route tree, receivers list
- Toolbar buttons: "Upload Config" (file picker), "Push to Mimir" (pushes current editor content), "Delete Config" (destructive, confirmation required)
- Footer: connected status, line count

### 3. Alerts

**Purpose:** View currently firing and pending alerts from the Mimir ruler.

**How alerts are fetched:**
- `mimirtool` has no direct alerts-list command. Alerts are fetched via a direct HTTP GET to `<env-url>/api/prom/api/v1/alerts` with the appropriate `X-Scope-OrgID` / custom headers from the active environment. This is the one exception to the "all calls go through mimirtool" rule — it uses `URLSession` directly.

**UI:**
- Filter chips: All / Firing / Pending
- Search pill: filter by label key=value
- Table: Alert Name, State badge (firing = red, pending = amber), Labels (pill tags), Duration
- Sidebar nav count badge turns red when firing alerts > 0
- Auto-refresh option (30s interval toggle)
- Footer: last refreshed timestamp

### 4. Remote Read

**Purpose:** Query raw metric samples from Mimir via remote read.

**mimirtool commands used:**
- `mimirtool remote-read export --selector <sel> --from <ts> --to <ts> --output-file <file>`

**UI:**
- Query form card: Selector input (monospace, full width), From / To datetime inputs, Export CSV button, Run Query button
- Results card: table of Metric name, Labels, Latest Value, Timestamp; row count + query duration in footer
- Export button writes results to a user-chosen file via save panel

### 5. Settings

**Purpose:** Manage environments, binary path, TLS/connection settings, and general preferences.

**Sections:**

**Environments**
- List rows: active indicator dot, name, URL (monospace), tenant/org-id, Edit / Delete buttons
- "+ Add Environment" button opens a sheet with all environment fields
- Clicking a non-active environment row switches the active environment app-wide
- The environment switcher chip in the sidebar opens a popover listing all environments for quick switching without going to Settings

**mimirtool Binary**
- Path field (monospace) pre-filled with auto-detected path
- "detected" green badge when found automatically
- "Browse…" button opens file picker for manual override

**TLS & Connection**
- Skip TLS Verify toggle
- CA Cert Path field + Browse button
- Timeout string field (e.g. `30s`)
- Retries integer field

**General**
- Log Level dropdown (info / debug / warn / error)
- Verbose Output toggle (shows raw mimirtool stdout in a log drawer)

---

## Navigation

Left sidebar, fixed width ~230pt:

```
[Environment switcher chip]  ← shows active env name + URL, click to switch

VIEWS
  📋 Rules          [count]
  🔔 Alertmanager
  ⚡  Alerts         [count, red when firing]
  🔍 Remote Read

TOOLS
  ⚙️  Settings

─────────────────────────
↺ Refresh              ⌘⇧R
mimirtool v0.x.x       [theme toggle]
```

---

## Visual Design

- **Style:** Dark-only, WailBrew-inspired
- **Background:** `#242424` (content area), `#1e1e1e` (sidebar), `#1e1e1e` (cards)
- **Cards:** Rounded corners (10pt), `1px` border `#2e2e2e`, SwiftUI `.shadow(color: .black.opacity(0.45), radius: 8, y: 4)` for lift
- **Active nav item:** Blue tint background `#2b3f5c`, blue text `#7ab3f0`
- **Tags:** Coloured tint backgrounds — blue for namespace, red for alerting, green for recording
- **Status dot:** Green `#4ade80` when connected
- **Firing badge:** Red `#f87171` on dark red background
- **Typography:** SF Pro Text system font throughout; SF Mono for all code/YAML/selectors

---

## Error Handling

- `MimirtoolRunner` returns a `Result<Output, MimirError>` where `MimirError` wraps stderr + exit code
- ViewModels expose `errorMessage: String?` shown as an inline banner above the table card
- Binary not found → Settings sheet opens automatically with a prompt to set the path
- Connection errors surface in the status bar (red dot + short message)

---

## Out of Scope (v1)

- Light mode
- Multi-window
- Rule syntax validation (beyond what mimirtool reports)
- Grafana dashboard analysis (`mimirtool analyze`)
- Backfill (`mimirtool backfill`)
- Auto-update of mimirtool binary itself
