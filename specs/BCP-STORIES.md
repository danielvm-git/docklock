# Big DockLocker — BCP-Aware Stories

Complete specification for macOS Dock anti-jumping app, using BCP-aware story format.

---

# 1. Monitor-Dock-Events: Background Accessibility Monitoring

**BCP Level (Estimated):** M3

## Business Objective
Continuously monitor macOS Dock window for position/size changes so the app can detect when the Dock is about to jump (or has jumped) due to system events (screen rotation, resolution change, app launch/close). This is the **sensing layer** for the entire anti-jump mechanism.

## Scope Boundaries
- **In scope:** Monitoring via macOS Accessibility and CoreGraphics APIs; detecting Dock position deltas; triggering lock evaluation.
- **Out of scope:** Actually preventing the jump (see Lock-Dock-Position story); user configuration (see Configure-Lock-Behavior).

---

## Business Rules
- **Rule 1:** Monitoring only starts if accessibility permissions are granted (checked at app launch and monitored for revocation).
- **Rule 2:** Position monitoring must trigger at least once per second; missing 3 consecutive checks = treat as permission loss.
- **Rule 3:** Only respond to *macOS-initiated* Dock moves; user-dragging the Dock is allowed and must not trigger lock logic.
- **Rule 4:** Detect position delta only; if delta < 1 pixel, do not trigger downstream rules (ignore noise).

## Interface Elements
None (background process). Log output available to Dashboard for debugging.

## Roles & Permissions
- **System User (implicit):** Requires macOS Accessibility permission for Dock monitoring. Without it, story fails silently and reports degradation to Dashboard.

## Solution Variabilities
- **Monitor Frequency:** Configurable via DockConfiguration.monitoringIntervalMs (default: 500ms). Lower = more responsive, higher CPU; higher = lower power, slower response.
- **Delta Threshold:** Configurable via DockConfiguration.positionDeltaThreshold (default: 1 pixel).

## Domain Entities

### Existing Entities (Count: 1)
- **DockConfiguration:** App-wide config; read to fetch monitoringIntervalMs and positionDeltaThreshold.

### New Domain Entities (Count: 2)
- **DockMonitorState:** Tracks current Dock position (x, y, width, height), last-checked timestamp, permission status. Ephemeral (memory-only).
- **DockPositionDelta:** Event raised when Dock position changes by ≥ positionDeltaThreshold. Contains {previousRect, currentRect, deltaX, deltaY, isMacOSInitiated}.

## Boundaries & Entity Interactions
- **Layer Boundary (System → App):** CoreGraphics / Accessibility APIs provide Dock window rect and event stream. App reads and buffers into DockMonitorState.
- **Cross-Component Boundary:** DockPositionDelta events flow from Monitor → Lock (story 2) → EventLog (story 6).

## Background Processes
- **Process 1: Dock Position Sampler**
  - Trigger: Timer (every DockConfiguration.monitoringIntervalMs milliseconds).
  - Frequency: Continuous while app is running.
  - Outcome: Updates DockMonitorState; emits DockPositionDelta event if delta ≥ threshold.
  
- **Process 2: Permission Check Watcher**
  - Trigger: On app launch; re-check every 10 seconds.
  - Outcome: Updates DockMonitorState.permissionStatus; emits PermissionLostEvent if permissions revoked.

## Notifications & Events
- **DockPositionDelta:** Emitted when Dock moves; consumed by Lock-Dock-Position (story 2).
- **PermissionLostEvent:** Emitted if accessibility permissions are revoked; consumed by Handle-System-Permissions (story 5) and Display-Lock-Status (story 4).

## Audits
- **Audit 1:** Every DockPositionDelta logged with timestamp, delta values, and isMacOSInitiated flag (used for forensics if lock doesn't fire).

---

## Acceptance Criteria

- [ ] **AC1:** Dock position sampler runs at exactly DockConfiguration.monitoringIntervalMs frequency (±10%).
- [ ] **AC2:** DockPositionDelta is emitted only when |deltaX| + |deltaY| ≥ positionDeltaThreshold.
- [ ] **AC3:** Position sampling stops gracefully if accessibility permission is lost; no crashes or polling storms.
- [ ] **AC4:** isMacOSInitiated flag correctly distinguishes system-triggered moves from user drags (may use Accessibility API event source or heuristics).
- [ ] **AC5:** Audit trail records every DockPositionDelta with timestamp and delta details.

## Test Cases (TDD Style)

### Happy Path: Normal Dock Move
```gherkin
Given a running Monitor-Dock-Events with accessibility permissions
 When the Dock moves 10 pixels left due to app launch
 Then DockPositionDelta event is emitted within 1 second
  And audit logs the move with isMacOSInitiated = true
```

### Edge Case: Permission Loss During Monitoring
```gherkin
Given a running Monitor-Dock-Events with active monitoring
 When accessibility permissions are revoked by user
 Then monitoring stops within 10 seconds
  And PermissionLostEvent is emitted
  And Dashboard is notified; user sees "Accessibility permission lost"
```

### Edge Case: User Drag (Should NOT trigger lock)
```gherkin
Given Monitor-Dock-Events is monitoring
 When user drags Dock manually (e.g., left edge of screen to bottom)
 Then isMacOSInitiated flag is set to false
  And Lock-Dock-Position is NOT triggered
  And audit logs the drag but marks it as user-initiated
```

### Edge Case: Sub-threshold Jitter
```gherkin
Given DockConfiguration.positionDeltaThreshold = 5 pixels
 When Dock position fluctuates by 2 pixels (noise)
 Then no DockPositionDelta event is emitted
  And no audit entry is created
```

---

## Complexity Summary

| Dimension | Count | Notes |
|-----------|-------|-------|
| Business Rules | 4 | Permission required; monitoring frequency; macOS vs user moves; delta noise filtering |
| Interface Elements | 0 | Background process only |
| Roles/Permissions | 1 | System Accessibility permission (binary) |
| Solution Variabilities | 2 | Monitor frequency; delta threshold |
| Domain Entities | 3 | DockConfiguration (existing), DockMonitorState, DockPositionDelta |
| Boundaries | 1 | Accessibility API ↔ App |
| Background Processes | 2 | Position sampler; permission watcher |
| Notifications | 2 | DockPositionDelta; PermissionLostEvent |
| Audits | 1 | Every delta logged |
| **Total BCP** | **M3** | 3–5 entities, 4 rules, 2 processes, straightforward Accessibility API usage |

---

# 2. Lock-Dock-Position: Prevent Dock Jump

**BCP Level (Estimated):** L5

## Business Objective
When the Dock is about to move (or just moved), use macOS system APIs to restore/lock its position so the user's workspace isn't disrupted. This is the **action layer** that actually prevents the jump.

## Scope Boundaries
- **In scope:** Restoring Dock position via CGWindowListCreateImage, user config (lock enabled/disabled, lock mode).
- **Out of scope:** Detecting when to lock (Monitor-Dock-Events handles that); UI (Configure-Lock-Behavior); logging (Log Events).

---

## Business Rules
- **Rule 1:** Lock only executes if DockConfiguration.lockEnabled = true AND app has active accessibility permissions.
- **Rule 2:** Lock always restores Dock to its *previous* position (before the delta); never applies a "preferred" position.
- **Rule 3:** Lock must complete within 200ms of detecting a Dock move (latency requirement).
- **Rule 4:** If lock fails (e.g., Dock is being resized by user), silently retry up to 3 times at 50ms intervals; if still failing, emit LockFailedEvent.
- **Rule 5:** When Dock is locked, a visual indicator (badge or glow) appears on Dock to signal lock is active (see story 4, Display-Lock-Status).

## Interface Elements
- **Visual Indicator:** Small locked badge or glow on Dock (or in menu bar) when lock is active; disappears when Dock is unlocked.

## Roles & Permissions
- **System User (implicit):** Requires macOS Accessibility permission to move Dock programmatically.

## Solution Variabilities
- **Lock Mode:** Hard vs soft lock (future: hard = force to exact pixel; soft = only prevent jumps >50 pixels). Currently: hard lock only.
- **Retry Count:** Configurable via DockConfiguration.lockRetryCount (default: 3).
- **Retry Delay:** Configurable via DockConfiguration.lockRetryDelayMs (default: 50ms).

## Domain Entities

### Existing Entities (Count: 3)
- **DockConfiguration:** Provides lockEnabled, lockRetryCount, lockRetryDelayMs.
- **DockMonitorState:** Contains previousRect (position to restore to); updated by Monitor-Dock-Events.
- **DockPositionDelta:** Consumed to trigger lock; contains previous/current rects and isMacOSInitiated flag.

### New Domain Entities (Count: 3)
- **LockState:** Tracks current lock status (locked/unlocked), active lock position, last lock timestamp, retry count. Updated during lock operations.
- **LockAttempt:** Event emitted when lock is attempted; contains delta details, retry number, outcome (success/failure/retry).
- **LockFailedEvent:** Emitted when lock fails after all retries; contains error details and Dock state snapshot.

## Boundaries & Entity Interactions
- **Layer Boundary (Accessibility API):** CGWindowListCreateImage and Dock manipulation APIs. Errors are caught and logged.
- **Cross-Component Boundary:** Consumes DockPositionDelta from Monitor; emits LockAttempt/LockFailedEvent to EventLog (story 6) and Display-Lock-Status (story 4).

## Background Processes
- **Process 1: Lock Executor**
  - Trigger: DockPositionDelta event (from Monitor-Dock-Events).
  - Outcome: Restores Dock to previousRect; updates LockState; emits LockAttempt.

- **Process 2: Lock Retry Handler**
  - Trigger: LockAttempt with outcome = failure.
  - Outcome: Waits DockConfiguration.lockRetryDelayMs, retries lock up to lockRetryCount times; emits final LockFailedEvent if all retries exhausted.

## Notifications & Events
- **LockAttempt:** Emitted after every lock try; consumed by EventLog (story 6) and Dashboard (story 4) for status display.
- **LockFailedEvent:** Emitted after max retries exhausted; alerts user via Dashboard notification (see story 4).
- **DockLockedVisualIndicator:** UI signal to Display-Lock-Status to show lock badge.

## Audits
- **Audit 1:** Every LockAttempt (success, retry, or failure) logged with timestamp, delta details, retry number, and outcome.

---

## Acceptance Criteria

- [ ] **AC1:** Lock executes only if lockEnabled = true AND accessibility permissions are active.
- [ ] **AC2:** Lock restores Dock to previousRect position within 200ms.
- [ ] **AC3:** If lock fails, retries up to lockRetryCount times with lockRetryDelayMs delay; silently succeeds if any attempt succeeds.
- [ ] **AC4:** LockFailedEvent emitted only after all retries exhausted; not on every failure.
- [ ] **AC5:** Visual indicator appears on Dock during lock; disappears when lock is released.
- [ ] **AC6:** Audit trail records every LockAttempt with outcome (success/retry/failure).

## Test Cases (TDD Style)

### Happy Path: Lock Succeeds
```gherkin
Given DockConfiguration.lockEnabled = true, accessibility permissions active, and Dock moves 20 pixels right
 When Monitor-Dock-Events emits DockPositionDelta
 Then Lock-Dock-Position restores Dock to previousRect within 200ms
  And LockState.locked = true
  And visual indicator appears on Dock
  And audit logs LockAttempt with outcome = success
```

### Edge Case: Lock Fails, Then Succeeds on Retry
```gherkin
Given a DockPositionDelta event and Dock is being resized by user
 When lock executor attempts to restore position
 Then attempt 1 fails (Dock locked by user action)
  And retry handler waits 50ms
  And attempt 2 succeeds
  And audit logs both attempts; final outcome = success
```

### Edge Case: Lock Fails All Retries
```gherkin
Given a DockPositionDelta and Dock remains locked after all retries
 When lock executor exhausts retries
 Then LockFailedEvent is emitted
  And Dashboard notification alerts user: "Failed to lock Dock position"
  And audit logs all 3 attempts with final outcome = failure
```

### Edge Case: lockEnabled = false
```gherkin
Given DockConfiguration.lockEnabled = false
 When Monitor-Dock-Events emits DockPositionDelta
 Then Lock-Dock-Position is NOT called
  And Dock moves normally without lock intervention
```

---

## Complexity Summary

| Dimension | Count | Notes |
|-----------|-------|-------|
| Business Rules | 5 | Lock only if enabled; restore to previous; latency SLA; retry logic; visual feedback |
| Interface Elements | 1 | Visual lock indicator on Dock |
| Roles/Permissions | 1 | System Accessibility permission |
| Solution Variabilities | 3 | Lock mode (hard/soft future); retry count; retry delay |
| Domain Entities | 6 | DockConfiguration, DockMonitorState, DockPositionDelta, LockState, LockAttempt, LockFailedEvent |
| Boundaries | 1 | Accessibility/CoreGraphics API for Dock manipulation |
| Background Processes | 2 | Lock executor; retry handler |
| Notifications | 3 | LockAttempt; LockFailedEvent; VisualIndicator |
| Audits | 1 | Every attempt (success/retry/failure) |
| **Total BCP** | **L5** | 6 entities, 5 rules, 2 processes, retry logic, visual feedback, Accessibility API complexity |

---

# 3. Configure-Lock-Behavior: Dashboard Settings

**BCP Level (Estimated):** M3

## Business Objective
Provide a user-facing macOS dashboard (SwiftUI window) where users can enable/disable lock, adjust monitoring frequency, set retry behavior, and view current lock status. This is the **configuration layer**.

## Scope Boundaries
- **In scope:** Dashboard UI, settings storage (DockConfiguration), real-time status display.
- **Out of scope:** Actual locking logic (story 2); event logging (story 6).

---

## Business Rules
- **Rule 1:** All changes to DockConfiguration are persisted immediately to disk (macOS UserDefaults or Keychain for sensitive values).
- **Rule 2:** lockEnabled toggle takes effect immediately; no restart required.
- **Rule 3:** monitoringIntervalMs and lockRetryDelayMs must be bounded: min 100ms, max 5000ms (prevent excessive CPU or unresponsiveness).
- **Rule 4:** User can only access dashboard if accessibility permissions are already granted; dashboard shows permission grant UI otherwise.

## Interface Elements
- **Dashboard Window:** Main SwiftUI window with:
  - Toggle: "Lock Dock Position" (enables/disables Monitor-Dock-Events and Lock-Dock-Position).
  - Slider: Monitoring Frequency (100ms to 5000ms, labeled "Responsive" ↔ "Power-saving").
  - Slider: Lock Retry Count (1 to 10).
  - Slider: Lock Retry Delay (10ms to 500ms).
  - Status Panel: Current Dock position (x, y), lock state (locked/unlocked), last lock timestamp.
  - Log View: Last 20 events (monitoring, lock attempts, errors).
  - Button: "Grant Accessibility Permission" (if not granted).
  - Checkbox: "Log Events to File" (for debugging).

## Roles & Permissions
- **App Admin (implicit local user):** Full read/write to all settings. No fine-grained roles (single-user app).

## Solution Variabilities
- **Dark/Light Mode:** Dashboard respects system appearance settings.
- **Window State:** User can resize/reposition dashboard; last position is remembered (persisted via NSWindow coding).
- **Log Detail Level:** User can toggle between normal and verbose logging (updates DockConfiguration.logLevel).

## Domain Entities

### Existing Entities (Count: 1)
- **DockConfiguration:** Persisted settings; read/written by dashboard.

### New Domain Entities (Count: 2)
- **DashboardState:** UI state (window position/size, expanded panels, scroll positions). Ephemeral or lightly persisted.
- **UserPreference:** Display preferences (dark mode, log verbosity, pin dashboard to top). Persisted alongside DockConfiguration.

## Boundaries & Entity Interactions
- **Persistence Boundary:** DockConfiguration serialized to macOS UserDefaults or .plist file; reads/writes at every user action.
- **IPC Boundary:** Dashboard sends config changes to background Monitor and Lock processes; receives status updates via notifications.

## Background Processes
- **Process 1: Configuration Apply**
  - Trigger: User changes any setting (toggle, slider, checkbox).
  - Outcome: Persists to disk; emits ConfigurationChangedEvent to Monitor and Lock; updates Dashboard UI to reflect applied state.

## Notifications & Events
- **ConfigurationChangedEvent:** Emitted when user changes settings; consumed by Monitor-Dock-Events and Lock-Dock-Position.
- **StatusUpdateEvent:** Received by Dashboard from Monitor/Lock to display current Dock position, lock state, recent events.

## Audits
- **Audit 1:** Every configuration change logged with timestamp, setting name, old value, new value. (May be in dashboard app log, not security audit.)

---

## Acceptance Criteria

- [ ] **AC1:** Dashboard window displays all required controls (toggles, sliders, status panel, log view).
- [ ] **AC2:** Changing lockEnabled toggle updates DockConfiguration and takes effect within 500ms.
- [ ] **AC3:** Sliders enforce min/max bounds (100–5000ms for frequency; 1–10 for retry count; 10–500ms for delay).
- [ ] **AC4:** All changes are persisted to disk immediately; no data loss on app crash.
- [ ] **AC5:** If accessibility permissions not granted, dashboard shows permission grant UI and disables lock controls.
- [ ] **AC6:** Status panel updates with Dock position and lock state at least every 1 second.
- [ ] **AC7:** Log view shows last 20 events and auto-scrolls to newest event.

## Test Cases (TDD Style)

### Happy Path: Enable Lock
```gherkin
Given Dashboard is open and accessibility permissions are granted
 When user toggles "Lock Dock Position" to ON
 Then DockConfiguration.lockEnabled is set to true
  And configuration is persisted to disk
  And Monitor-Dock-Events starts monitoring
  And Dashboard status shows "Lock: Active"
```

### Edge Case: Frequency Slider Out of Bounds
```gherkin
Given frequency slider allows input 0–10000ms
 When user attempts to set frequency to 50ms (below min 100ms)
 Then slider snaps to 100ms
  And tooltip shows "Minimum 100ms (responsive)"
  And configuration is set to 100ms
```

### Edge Case: Permission Grant Flow
```gherkin
Given Dashboard is open and accessibility permissions NOT granted
 When Dashboard is visible
 Then lock controls are disabled
  And button "Grant Accessibility Permission" is visible and clickable
 When user clicks button
 Then system prompts for Accessibility permission
  And Dashboard waits for permission response
  And on grant, lock controls are enabled
```

### Edge Case: Config Changes During Lock
```gherkin
Given Lock-Dock-Position is actively locking
 When user changes lockRetryDelayMs to 100ms (from 50ms)
 Then configuration is persisted
  And in-progress retry handler uses NEW delay (100ms) for next retry
  And audit logs config change with timestamp
```

---

## Complexity Summary

| Dimension | Count | Notes |
|-----------|-------|-------|
| Business Rules | 4 | Immediate persistence; immediate effect; bounds checking; permission gate |
| Interface Elements | 8+ | Toggle, sliders (3×), status panel, log view, permission button, checkbox |
| Roles/Permissions | 1 | Single local admin (no fine-grained roles) |
| Solution Variabilities | 3 | Dark/light mode; window state; log verbosity |
| Domain Entities | 3 | DockConfiguration, DashboardState, UserPreference |
| Boundaries | 2 | UserDefaults/persistence; IPC to Monitor/Lock |
| Background Processes | 1 | Configuration apply handler |
| Notifications | 2 | ConfigurationChangedEvent (out); StatusUpdateEvent (in) |
| Audits | 1 | Configuration changes logged |
| **Total BCP** | **M3** | 3 entities, 4 rules, straightforward UI, bound sliders, real-time sync |

---

# 4. Display-Lock-Status: Real-time Dashboard Status

**BCP Level (Estimated):** S2

## Business Objective
Display real-time lock status, Dock position, and recent events in the dashboard so users can see that the lock is working. Visual feedback builds user confidence and aids debugging.

## Scope Boundaries
- **In scope:** Consuming events from Monitor/Lock; rendering status on Dashboard; visual lock indicator on Dock.
- **Out of scope:** Accepting user input (story 3 handles configuration).

---

## Business Rules
- **Rule 1:** Status panel updates at least every 1 second with current Dock position and lock state.
- **Rule 2:** Lock indicator (badge/glow on Dock) appears within 100ms of a lock event; disappears within 500ms of lock completion.
- **Rule 3:** If monitoring is paused/stopped (permission lost), status shows "Monitoring: Paused" in red.
- **Rule 4:** Event log in Dashboard displays events in reverse chronological order; truncates to last 50 events.

## Interface Elements
- **Status Panel:**
  - Dock Position: Display (x, y) in real-time.
  - Lock State: "Locked" / "Unlocked" with color coding (green = locked/safe, gray = unlocked/normal).
  - Last Lock Timestamp: "Locked at HH:MM:SS" or "Never".
  - Monitoring Status: "Monitoring: Active" (green) or "Monitoring: Paused" (red with reason).
  
- **Lock Indicator on Dock (or menu bar):** Small badge showing lock icon, appears/disappears with lock state.

- **Event Log View:**
  - Displays last 50 events (Monitor-Dock-Events, LockAttempt, LockFailedEvent, PermissionLostEvent).
  - Columns: Timestamp, Event Type, Details.
  - Auto-scrolls to newest event.

## Roles & Permissions
- **User (implicit):** Read-only view of status and logs.

## Solution Variabilities
- **Status Refresh Rate:** Configurable via DockConfiguration.statusRefreshRateMs (default: 1000ms, i.e., 1 per second).
- **Log Retention:** Configurable via DockConfiguration.logRetentionCount (default: 50 events).

## Domain Entities

### Existing Entities (Count: 4)
- **DockConfiguration:** Provides statusRefreshRateMs, logRetentionCount.
- **DockMonitorState:** Current Dock position.
- **LockState:** Current lock status and timestamp.
- **DashboardState:** UI state (panel visibility, scroll position).

### New Domain Entities (Count: 1)
- **EventLog:** In-memory (or lightly persisted) log of recent events (monitoring deltas, lock attempts, errors).

## Boundaries & Entity Interactions
- **Event Stream Boundary:** Monitor, Lock, Permission systems emit events → EventLog → Dashboard consumes and displays.

## Background Processes
- **Process 1: Status Refresh Loop**
  - Trigger: Timer (every statusRefreshRateMs).
  - Outcome: Reads DockMonitorState, LockState; updates Dashboard status panel.

- **Process 2: Event Log Sink**
  - Trigger: Any event emitted (DockPositionDelta, LockAttempt, LockFailedEvent, PermissionLostEvent).
  - Outcome: Appends to EventLog; truncates to logRetentionCount; notifies Dashboard to re-render.

## Notifications & Events
- **StatusUpdateEvent:** Emitted by status refresh loop; consumed by Dashboard to render status panel.
- **EventAddedEvent:** Emitted by event log sink; consumed by Dashboard to update event list.
- **LockIndicatorToggleEvent:** Emitted to Dock/menu bar to show/hide lock badge.

## Audits
- **Audit 1:** Event log is audit trail; every significant event is recorded (inherits from Monitor, Lock, Permissions stories).

---

## Acceptance Criteria

- [ ] **AC1:** Status panel updates with Dock position and lock state at least every 1 second (within statusRefreshRateMs).
- [ ] **AC2:** Lock indicator appears on Dock within 100ms of lock event; disappears within 500ms of event completion.
- [ ] **AC3:** If monitoring is paused, status shows "Monitoring: Paused" in red with reason (e.g., "Permission lost").
- [ ] **AC4:** Event log displays last 50 events in reverse chronological order; truncates oldest events when limit exceeded.
- [ ] **AC5:** Dashboard refreshes smoothly without blocking user interaction during status updates.

## Test Cases (TDD Style)

### Happy Path: Lock Event Visible
```gherkin
Given Dashboard is open and monitoring is active
 When Lock-Dock-Position executes a lock
 Then LockAttempt event appears in event log within 200ms
  And lock indicator appears on Dock within 100ms
  And status panel shows "Lock State: Locked"
  And lock indicator disappears within 500ms of lock completion
```

### Edge Case: Event Log Full
```gherkin
Given event log retention is set to 50 events
 When 51st event arrives
 Then oldest event is removed
  And newest event is appended
  And event log still shows exactly 50 events
```

### Edge Case: Permission Lost During Monitoring
```gherkin
Given monitoring is active and status shows "Monitoring: Active"
 When accessibility permissions are revoked
 Then PermissionLostEvent is emitted
  And status panel immediately updates to "Monitoring: Paused" in red
  And log shows "Permission lost" event
```

---

## Complexity Summary

| Dimension | Count | Notes |
|-----------|-------|-------|
| Business Rules | 4 | Status refresh rate; indicator timing; permission loss display; log retention |
| Interface Elements | 3 | Status panel, lock indicator, event log view |
| Roles/Permissions | 1 | User (read-only) |
| Solution Variabilities | 2 | Refresh rate; log retention count |
| Domain Entities | 5 | DockConfiguration, DockMonitorState, LockState, DashboardState, EventLog |
| Boundaries | 1 | Event stream from Monitor/Lock → Dashboard |
| Background Processes | 2 | Status refresh loop; event log sink |
| Notifications | 3 | StatusUpdateEvent; EventAddedEvent; LockIndicatorToggleEvent |
| Audits | 1 | Event log as audit trail |
| **Total BCP** | **S2** | 5 entities, 4 rules, straightforward event display; no complex logic |

---

# 5. Handle-System-Permissions: Accessibility Permission Management

**BCP Level (Estimated):** S2

## Business Objective
Request, verify, and monitor macOS Accessibility permissions (required for Dock monitoring and positioning). Gracefully degrade if permissions are lost at runtime.

## Scope Boundaries
- **In scope:** Permission request flow; periodic permission verification; graceful degradation on loss.
- **Out of scope:** Explaining why permissions are needed (story 3 dashboard has a help section).

---

## Business Rules
- **Rule 1:** App cannot start monitoring or locking without Accessibility permission; permission check happens at launch.
- **Rule 2:** If permission is not granted at launch, show permission grant UI in Dashboard; disable lock controls.
- **Rule 3:** Permission is re-checked every 30 seconds during runtime (background process). If revoked, emit PermissionLostEvent and pause monitoring.
- **Rule 4:** On permission grant (or recovery), emit PermissionGrantedEvent; resume monitoring if it was previously active.

## Interface Elements
- **Permission Grant UI (in Dashboard):**
  - Button: "Grant Accessibility Permission"
  - Text: "Big DockLocker needs Accessibility permission to monitor and control the Dock. Click below to open System Preferences."
  - Result: Opens macOS System Preferences > Security & Privacy > Accessibility.

## Roles & Permissions
- **User (implicit):** Must grant macOS Accessibility permission in System Preferences.

## Solution Variabilities
- **Permission Check Interval:** Configurable via DockConfiguration.permissionCheckIntervalMs (default: 30000ms = 30 seconds).

## Domain Entities

### Existing Entities (Count: 1)
- **DockConfiguration:** Provides permissionCheckIntervalMs.

### New Domain Entities (Count: 2)
- **PermissionStatus:** Enum (granted, denied, unknown). Tracks current permission state.
- **PermissionCheckResult:** Event emitted when permission is checked; contains status and timestamp.

## Boundaries & Entity Interactions
- **System Boundary:** macOS Accessibility API / Security & Privacy system preferences.
- **Event Boundary:** PermissionLostEvent triggers pause of Monitor/Lock processes; PermissionGrantedEvent resumes them.

## Background Processes
- **Process 1: Permission Checker**
  - Trigger: On app launch; then every permissionCheckIntervalMs.
  - Outcome: Checks if Accessibility permission is granted; emits PermissionCheckResult and (if changed) PermissionLostEvent or PermissionGrantedEvent.

## Notifications & Events
- **PermissionCheckResult:** Emitted every 30 seconds with current status.
- **PermissionLostEvent:** Emitted if permission was granted and is now revoked; triggers pause of Monitor/Lock.
- **PermissionGrantedEvent:** Emitted if permission was denied and is now granted; triggers resume of Monitor/Lock.
- **PermissionGrantButton:** Clicked by user to open System Preferences.

## Audits
- **Audit 1:** Every permission check logged with timestamp and result (granted/denied).
- **Audit 2:** Permission loss/grant events logged for forensics.

---

## Acceptance Criteria

- [ ] **AC1:** App checks accessibility permission at launch; blocks lock functionality if not granted.
- [ ] **AC2:** If permission not granted, Dashboard shows permission grant UI with button to open System Preferences.
- [ ] **AC3:** Permission is re-checked every 30 seconds (configurable); no excessive system calls.
- [ ] **AC4:** If permission is revoked at runtime, monitoring and locking stop immediately; PermissionLostEvent emitted.
- [ ] **AC5:** If permission is restored, monitoring and locking resume; PermissionGrantedEvent emitted.
- [ ] **AC6:** All permission checks and changes are audited with timestamps.

## Test Cases (TDD Style)

### Happy Path: Permission Granted at Launch
```gherkin
Given user has granted Accessibility permission to Big DockLocker
 When app launches
 Then permission check succeeds
  And lock controls are enabled in Dashboard
  And monitoring starts automatically
  And audit logs "Permission: Granted"
```

### Edge Case: Permission Denied at Launch
```gherkin
Given user has NOT granted Accessibility permission
 When app launches
 Then permission check fails
  And Dashboard shows "Grant Accessibility Permission" button
  And lock controls are disabled (grayed out)
  And monitoring does not start
  And audit logs "Permission: Denied"
```

### Edge Case: Permission Revoked During Runtime
```gherkin
Given monitoring is active with permission granted
 When user revokes Accessibility permission in System Preferences
 Then permission checker detects revocation within 30 seconds
  And PermissionLostEvent is emitted
  And monitoring pauses
  And lock is disabled
  And Dashboard status shows "Monitoring: Paused (Permission lost)"
  And audit logs "Permission: Revoked"
```

### Edge Case: Permission Restored
```gherkin
Given monitoring is paused (permission lost)
 When user grants Accessibility permission in System Preferences
 Then permission checker detects grant within 30 seconds
  And PermissionGrantedEvent is emitted
  And monitoring resumes
  And lock is enabled
  And audit logs "Permission: Granted"
```

---

## Complexity Summary

| Dimension | Count | Notes |
|-----------|-------|-------|
| Business Rules | 4 | Permission required at launch; permission check interval; permission loss/grant events; disable/enable controls |
| Interface Elements | 1 | Permission grant UI (button + text) |
| Roles/Permissions | 1 | macOS Accessibility permission (binary) |
| Solution Variabilities | 1 | Permission check interval |
| Domain Entities | 3 | DockConfiguration, PermissionStatus, PermissionCheckResult |
| Boundaries | 1 | macOS System Preferences / Accessibility API |
| Background Processes | 1 | Permission checker (every 30 seconds) |
| Notifications | 3 | PermissionCheckResult; PermissionLostEvent; PermissionGrantedEvent |
| Audits | 2 | Every permission check; permission changes |
| **Total BCP** | **S2** | 3 entities, 4 rules, 1 background process, straightforward permission management |

---

# 6. Log-Anti-Jump-Events: Audit Trail & Debugging

**BCP Level (Estimated):** M3

## Business Objective
Maintain a persistent audit trail of all lock events (detection, attempts, failures, permission changes) for debugging, forensics, and user confidence. Enable users to export logs for support tickets.

## Scope Boundaries
- **In scope:** Capturing events from Monitor, Lock, Permissions; writing to file; log rotation; export UI.
- **Out of scope:** Real-time display (story 4 handles Dashboard display); event generation (stories 1, 2, 5).

---

## Business Rules
- **Rule 1:** Every significant event (DockPositionDelta, LockAttempt, LockFailedEvent, PermissionLostEvent) is logged to file.
- **Rule 2:** Logs are written to ~/Library/Logs/BigDockLocker/ with filename pattern BigDockLocker-YYYY-MM-DD.log.
- **Rule 3:** Logs rotate daily; logs older than 7 days are automatically deleted.
- **Rule 4:** User can toggle logging on/off via Dashboard (story 3); default is OFF to minimize disk I/O and privacy concerns.
- **Rule 5:** Log entries include timestamp, event type, delta details, outcome, and (if applicable) error messages.

## Interface Elements
- **Dashboard Checkbox:** "Log events to file" (toggle). When enabled, logs are written; when disabled, only in-memory event log remains.
- **Export Button:** "Export logs as .zip" (on Dashboard). Compresses logs and saves to Downloads folder.

## Roles & Permissions
- **User (implicit):** Can enable/disable logging and export logs via Dashboard.

## Solution Variabilities
- **Log Level:** Configurable via DockConfiguration.logLevel (normal vs. verbose). Verbose includes full Dock rect details; normal is higher-level.
- **Log Retention Days:** Configurable via DockConfiguration.logRetentionDays (default: 7 days).
- **Log File Path:** Configurable via DockConfiguration.logPath (default: ~/Library/Logs/BigDockLocker/).

## Domain Entities

### Existing Entities (Count: 5)
- **DockConfiguration:** Provides logLevel, logRetentionDays, logPath, loggingEnabled.
- **DockPositionDelta:** Event logged from Monitor story.
- **LockAttempt:** Event logged from Lock story.
- **LockFailedEvent:** Event logged from Lock story.
- **PermissionCheckResult:** Event logged from Permissions story.

### New Domain Entities (Count: 2)
- **LogEntry:** Structured log record (timestamp, eventType, details, outcome). Written to disk.
- **LogFile:** Handle to daily log file; manages file I/O and rotation.

## Boundaries & Entity Interactions
- **Event Boundary:** Monitor, Lock, Permissions systems emit events → LogFile captures and writes to disk.
- **File System Boundary:** Logs stored at ~/Library/Logs/BigDockLocker/BigDockLocker-YYYY-MM-DD.log; rotated/deleted daily.

## Background Processes
- **Process 1: Log Writer**
  - Trigger: Any event emitted (DockPositionDelta, LockAttempt, LockFailedEvent, PermissionCheckResult).
  - Outcome: Formats event into LogEntry; writes to current day's log file (if loggingEnabled = true).

- **Process 2: Log Rotation & Cleanup**
  - Trigger: Once daily (e.g., at midnight).
  - Outcome: Deletes logs older than logRetentionDays; archives current day's log if it exceeds size limit (e.g., 10MB).

## Notifications & Events
- **LogWriterStatusEvent:** Emitted periodically (e.g., hourly) to report log file size and retention status.
- **ExportLogsEvent:** Triggered by user clicking "Export logs as .zip" button.

## Audits
- **Audit 1:** Event log file is the audit trail; every significant event is recorded with full details.
- **Audit 2:** Log rotation and deletion are logged (meta-audit) in a separate log file for compliance.

---

## Acceptance Criteria

- [ ] **AC1:** Every DockPositionDelta, LockAttempt, LockFailedEvent, PermissionCheckResult is logged to file (if loggingEnabled = true).
- [ ] **AC2:** Log entries include timestamp, event type, relevant details (e.g., delta values), and outcome.
- [ ] **AC3:** Logs are stored in ~/Library/Logs/BigDockLocker/ with filename pattern BigDockLocker-YYYY-MM-DD.log.
- [ ] **AC4:** Logs rotate daily; logs older than logRetentionDays (default: 7) are deleted automatically.
- [ ] **AC5:** User can toggle logging on/off via Dashboard; loggingEnabled affects all log writers.
- [ ] **AC6:** User can export logs as .zip via Dashboard; .zip includes all log files from past 7 days.
- [ ] **AC7:** Log file writes do not block event processing (async/buffered writes).

## Test Cases (TDD Style)

### Happy Path: Log Event
```gherkin
Given loggingEnabled = true
 When DockPositionDelta event occurs
 Then LogEntry is created with timestamp, event type, delta values
  And LogEntry is written to BigDockLocker-YYYY-MM-DD.log
  And log file is readable and parseable
```

### Edge Case: Logging Disabled
```gherkin
Given loggingEnabled = false
 When DockPositionDelta and LockAttempt events occur
 Then no log file entries are written
  And in-memory event log (story 4) still records events for Dashboard display
```

### Edge Case: Log File Rotation
```gherkin
Given today's log file has 50 events
 When calendar advances to next day (midnight)
 Then rotation process runs
  And today's log file is finalized (no further writes)
  And new log file BigDockLocker-YYYY-MM-DD.log is created for new day
  And audit logs the rotation
```

### Edge Case: Log Retention Cleanup
```gherkin
Given log files from the past 7 days are present
 When cleanup process runs on day 8
 Then log files older than 7 days are deleted
  And log files from past 7 days are retained
  And meta-audit logs the deletion
```

### Edge Case: Export Logs
```gherkin
Given user has enabled logging for 3 days
 When user clicks "Export logs as .zip" in Dashboard
 Then system creates .zip with all 3 log files
  And saves to ~/Downloads/BigDockLocker-logs-YYYY-MM-DD.zip
  And user can extract and view logs
```

---

## Complexity Summary

| Dimension | Count | Notes |
|-----------|-------|-------|
| Business Rules | 5 | Every event logged; file rotation; auto-cleanup; toggle on/off; structured log format |
| Interface Elements | 2 | Dashboard logging checkbox; export button |
| Roles/Permissions | 1 | User can enable/disable and export |
| Solution Variabilities | 3 | Log level (normal/verbose); retention days; file path |
| Domain Entities | 7 | DockConfiguration, DockPositionDelta, LockAttempt, LockFailedEvent, PermissionCheckResult, LogEntry, LogFile |
| Boundaries | 1 | File system (~/Library/Logs/BigDockLocker/) |
| Background Processes | 2 | Log writer; rotation & cleanup |
| Notifications | 2 | LogWriterStatusEvent; ExportLogsEvent |
| Audits | 2 | Event log file + meta-audit for rotation/deletion |
| **Total BCP** | **M3** | 7 entities, 5 rules, 2 background processes, file rotation logic |

---

# 7. Recover-From-Permission-Loss: Graceful Degradation

**BCP Level (Estimated):** S2

## Business Objective
When accessibility permissions are revoked at runtime, gracefully stop monitoring and locking, alert the user, and provide a clear path to restore permissions without crashing or polling endlessly.

## Scope Boundaries
- **In scope:** Handling PermissionLostEvent; stopping Monitor/Lock; showing user notification; waiting for permission restoration.
- **Out of scope:** Permission check itself (story 5 handles that); detailed error messages (story 4 Dashboard shows status).

---

## Business Rules
- **Rule 1:** When PermissionLostEvent is detected, Monitor-Dock-Events immediately stops sampling; no further Dock position reads.
- **Rule 2:** When permissions are lost, Lock-Dock-Position is disabled and cannot execute even if DockConfiguration.lockEnabled = true.
- **Rule 3:** User is notified via Dashboard notification: "Accessibility permission lost. Click to restore." Notification is not intrusive (no modal).
- **Rule 4:** If permission is restored (user re-grants in System Preferences), monitoring and locking resume automatically if they were previously enabled.
- **Rule 5:** Permission check continues every 30 seconds (story 5) until permission is restored; no manual intervention required.

## Interface Elements
- **Dashboard Notification:** Non-modal notification bar at top of Dashboard: "Accessibility permission lost. [Restore]" with action button.

## Roles & Permissions
- **User (implicit):** Can restore permission via System Preferences; notification guides them.

## Solution Variabilities
- **Notification Style:** Configurable (inline banner vs. system notification). Default: inline banner in Dashboard.
- **Resume Behavior:** Configurable via DockConfiguration.autoResumeOnPermissionRestore (default: true). If true, monitoring/locking resume; if false, user must manually re-enable via Dashboard.

## Domain Entities

### Existing Entities (Count: 3)
- **DockConfiguration:** Provides autoResumeOnPermissionRestore.
- **DockMonitorState:** Paused when permission lost.
- **LockState:** Locked status frozen; no new locks.

### New Domain Entities (Count: 1)
- **PermissionRecoveryState:** Tracks that monitoring/locking were paused and should be resumed when permission is restored.

## Boundaries & Entity Interactions
- **Event Boundary:** PermissionLostEvent → Monitor/Lock pause; PermissionGrantedEvent → Monitor/Lock resume.

## Background Processes
- None specific to this story; leverages existing permission checker (story 5).

## Notifications & Events
- **PermissionLostEvent:** Consumed to pause Monitor/Lock and show notification.
- **PermissionGrantedEvent:** Consumed to resume Monitor/Lock (if autoResumeOnPermissionRestore = true).

## Audits
- **Audit 1:** Permission loss and recovery logged; state transitions audited.

---

## Acceptance Criteria

- [ ] **AC1:** When PermissionLostEvent is detected, Monitor-Dock-Events immediately stops sampling.
- [ ] **AC2:** When permissions are lost, Lock-Dock-Position is disabled and ignores DockConfiguration.lockEnabled.
- [ ] **AC3:** Dashboard shows notification "Accessibility permission lost. [Restore]" with action button.
- [ ] **AC4:** When permission is restored, monitoring and locking resume if autoResumeOnPermissionRestore = true.
- [ ] **AC5:** No crashes or excessive polling when permissions are lost; graceful degradation.

## Test Cases (TDD Style)

### Happy Path: Permission Lost → Restored
```gherkin
Given monitoring is active with permissions granted
 When accessibility permission is revoked
 Then PermissionLostEvent is emitted
  And Monitor-Dock-Events stops sampling
  And Lock-Dock-Position is disabled
  And Dashboard shows "Accessibility permission lost. [Restore]"
 When user grants permission again
 Then PermissionGrantedEvent is emitted (by story 5 checker)
  And monitoring resumes
  And lock is enabled
  And Dashboard notification is cleared
  And audit logs permission loss and restoration
```

### Edge Case: Permission Lost, autoResumeOnPermissionRestore = false
```gherkin
Given DockConfiguration.autoResumeOnPermissionRestore = false
 When permission is restored
 Then monitoring and locking do NOT automatically resume
  And user must manually re-enable via Dashboard toggle
  And audit notes manual resumption
```

---

## Complexity Summary

| Dimension | Count | Notes |
|-----------|-------|-------|
| Business Rules | 5 | Stop monitoring on loss; disable locking; notify user; auto-resume (configurable); continuous checking |
| Interface Elements | 1 | Dashboard notification bar |
| Roles/Permissions | 1 | User (implicit) |
| Solution Variabilities | 2 | Notification style; auto-resume behavior |
| Domain Entities | 4 | DockConfiguration, DockMonitorState, LockState, PermissionRecoveryState |
| Boundaries | 0 | Internal event handling |
| Background Processes | 0 | Leverages existing permission checker |
| Notifications | 2 | PermissionLostEvent; PermissionGrantedEvent |
| Audits | 1 | Permission loss/recovery state transitions |
| **Total BCP** | **S2** | 4 entities, 5 rules, simple state management, no new processes |

---

## Summary Table: All Stories

| Story | BCP | Business Rules | Interface | Entities | Processes | Key Complexity |
|-------|-----|---|---|---|---|---|
| 1. Monitor-Dock-Events | M3 | 4 | 0 | 3 | 2 | Accessibility API, continuous sampling |
| 2. Lock-Dock-Position | L5 | 5 | 1 | 6 | 2 | Retry logic, visual feedback, CoreGraphics |
| 3. Configure-Lock-Behavior | M3 | 4 | 8+ | 3 | 1 | Dashboard settings, bound sliders, real-time sync |
| 4. Display-Lock-Status | S2 | 4 | 3 | 5 | 2 | Real-time display, event log |
| 5. Handle-System-Permissions | S2 | 4 | 1 | 3 | 1 | Permission lifecycle, runtime checks |
| 6. Log-Anti-Jump-Events | M3 | 5 | 2 | 7 | 2 | File rotation, log cleanup |
| 7. Recover-From-Permission-Loss | S2 | 5 | 1 | 4 | 0 | Graceful degradation, state recovery |
| **TOTAL** | **~L5 (avg: M)** | **31** | **16** | **35** | **10** | Full app complexity: background monitoring + UI + config + logging |

---

## How to Use This Spec

1. **For Development (TDD):**
   - Each story lists test cases; write tests first.
   - Acceptance criteria must pass before marking story done.
   - Audit requirements are non-optional.

2. **For BCP Counting:**
   - Sum the "Count" columns in each story's complexity table.
   - Consult BCR matrix with totals to assign overall app complexity.
   - Example: 31 business rules + 10 processes → likely L–XL range (depending on entity relationships).

3. **For Prioritization:**
   - Stories 1 (Monitor), 2 (Lock), 5 (Permissions) are **critical path** (MVP).
   - Stories 3 (Configure), 4 (Display) are **essential UX** (1st release).
   - Stories 6 (Logging), 7 (Recovery) are **stability/polish** (2nd release).

4. **For Handoff:**
   - Each story is independently testable and deployable (SOLID principles).
   - Business rules are explicit and reviewable by domain experts (no hidden logic).
   - Complexity is transparent; no surprises mid-implementation.
