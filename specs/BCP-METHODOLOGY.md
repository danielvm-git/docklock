# Using BCP-Aware Stories to Count Business Complexity Correctly

## The Problem

Standard agile story formats (User Stories, BDD) focus on **user behavior** and **happy paths**. They miss the **business structure** that drives complexity:
- Hidden permission sets and roles
- Cross-system boundaries and entities
- Background processes and async logic
- Audit and compliance requirements
- Configuration variabilities and edge cases

Result: Developers estimate "S" → complexity reveals to be "L". Surprises, scope creep, and rework.

---

## The Solution: BCP-Aware Specification Stories

This template combines:
- **Spec-driven format** (bigpowers): Explicit, testable acceptance criteria and business rules.
- **BCP dimensions** (Business Complexity Ruler): 10 structured dimensions that capture all sources of complexity.
- **Structured sections** that force thinking about each dimension.

---

## Why This Works: Dimension Mapping

### 1. Business Rules
**BCR Definition:** Rules that must be enforced; violations have business consequences.

**Template Section:** "Business Rules"  
**Why It Works:** Lists rules explicitly. No hidden "requirements" buried in test cases or comments.

**Example (Story 2: Lock-Dock-Position):**
- Rule 1: Lock only if enabled AND permissions active → 1 gate, 2 dependencies.
- Rule 4: Retry up to N times → retry logic (complexity).
- Rule 5: Visual indicator → UI coupling.

**Counting:** Add up the rules. 5 rules = moderate complexity indicator.

---

### 2. Interface Elements
**BCR Definition:** UI/UX components, displays, inputs. Each is a source of complexity (validation, state sync, rendering).

**Template Section:** "Interface Elements"  
**Why It Works:** Lists every UI element and its purpose. No "just add a button" surprises.

**Example (Story 3: Configure-Lock-Behavior):**
- Toggle: enables/disables
- 3 Sliders: with bounds checking and real-time sync
- Status panel: displays Dock position
- Log view: displays last 50 events
- Permission button: opens System Preferences
- Checkbox: toggles logging

**Counting:** 8 UI elements. More elements = more state, validation, and synchronization logic.

---

### 3. Roles & Permissions
**BCR Definition:** Permission sets and their boundaries. Fine-grained permissions = higher complexity.

**Template Section:** "Roles & Permissions"  
**Why It Works:** Explicitly states who can do what. Authorization rules are visible and testable.

**Example (Story 1: Monitor-Dock-Events):**
- System User: requires Accessibility permission
- Monitoring only runs if permission is active

**Counting:** 1 role/permission set = simple. Multiple sets with interdependencies = complex.

---

### 4. Solution Variabilities
**BCR Definition:** Behavior that changes based on configuration, parameters, or runtime state.

**Template Section:** "Solution Variabilities"  
**Why It Works:** Parameterized behavior is visible; no hardcoded assumptions.

**Example (Story 1: Monitor-Dock-Events):**
- monitoringIntervalMs: configurable (500ms default, 100–5000ms range)
- positionDeltaThreshold: configurable

**Example (Story 2: Lock-Dock-Position):**
- Lock Mode: hard vs. soft (future)
- Retry Count: 1–10
- Retry Delay: 10–500ms

**Counting:** Each variability adds conditional logic branches. 3 variabilities = 3× more test cases.

---

### 5. Boundaries
**BCR Definition:** Cross-layer or cross-system boundaries where data/events flow. Each boundary is a potential integration point and failure mode.

**Template Section:** "Boundaries & Entity Interactions"  
**Why It Works:** Makes integration points explicit. Prevents "I didn't know Monitor and Lock were decoupled."

**Example (Story 1: Monitor-Dock-Events):**
- System Boundary: CoreGraphics / Accessibility APIs provide Dock window rect.
- Cross-Component Boundary: DockPositionDelta events flow from Monitor → Lock → EventLog.

**Example (Story 2: Lock-Dock-Position):**
- Layer Boundary: Accessibility API for Dock manipulation; errors caught and logged.
- Cross-Component Boundary: Consumes DockPositionDelta; emits LockAttempt/LockFailedEvent.

**Counting:** Each boundary = 1 integration point. 1 boundary = simple; 3+ = complex.

---

### 6. Domain Entities
**BCR Definition:** The amount of business data/state the story touches. More entities = more state to manage, test, and persist.

**Template Section:** "Domain Entities" (existing + new)  
**Why It Works:** Separates existing entities (no new complexity) from new ones (adds complexity). Counts both.

**Example (Story 2: Lock-Dock-Position):**
- **Existing:** DockConfiguration, DockMonitorState, DockPositionDelta (3 entities, inherit from other stories)
- **New:** LockState, LockAttempt, LockFailedEvent (3 new entities)
- **Total:** 6 entities involved in story.

**BCR Rule:** 1 entity = XS; 2–3 = S; 4–5 = M; 6–7 = L; 8+ = XL.

**Counting:** Sum new entities across all stories to get app-wide entity count. This is the strongest BCP signal.

---

### 7. New Domain Entity Interactions
**BCR Definition:** New attributes, relationships, or interactions between entities. Each relationship = more test coverage.

**Template Section:** "Domain Entities" (relationships between new entities)  
**Why It Works:** Some stories create 3 new entities with minimal relationships (S); others create 2 entities with complex relationships (M).

**Example (Story 6: Log-Anti-Jump-Events):**
- LogEntry references multiple event types (DockPositionDelta, LockAttempt, PermissionCheckResult, etc.).
- LogFile manages rotation and retention (relationship with filesystem).

**Counting:** More relationships = more test cases and serialization logic.

---

### 8. Background Processes
**BCR Definition:** Asynchronous, scheduled, or event-driven processes. Each process is a source of concurrency bugs and state synchronization complexity.

**Template Section:** "Background Processes"  
**Why It Works:** Lists triggers, frequency, and outcomes. No hidden async code.

**Example (Story 1: Monitor-Dock-Events):**
- Process 1: Dock Position Sampler (timer-based).
- Process 2: Permission Check Watcher (timer-based).

**Example (Story 2: Lock-Dock-Position):**
- Process 1: Lock Executor (event-triggered).
- Process 2: Lock Retry Handler (event-triggered with delay).

**Counting:** Each process = 1 source of async complexity. 10 processes across app = high complexity.

---

### 9. Notifications & Events
**BCR Definition:** Events sent to users or other systems. Each event = a messaging/coupling point.

**Template Section:** "Notifications & Events"  
**Why It Works:** Events are enumerated; senders and consumers are clear.

**Example (Story 1: Monitor-Dock-Events):**
- DockPositionDelta: Emitted to Lock (story 2) and EventLog (story 6).
- PermissionLostEvent: Emitted to Handle-System-Permissions (story 5) and Display-Lock-Status (story 4).

**Counting:** 2 events from story 1. 10+ events across app = integration points everywhere.

---

### 10. Audits
**BCR Definition:** Information trails for compliance, forensics, or debugging. Each audit requirement = more logging, storage, and retrieval logic.

**Template Section:** "Audits"  
**Why It Works:** Audit requirements are explicit; no "we'll add logging later" handwaving.

**Example (Story 2: Lock-Dock-Position):**
- Audit 1: Every LockAttempt (success, retry, or failure) logged with timestamp, delta details, retry number, and outcome.

**Counting:** 1 audit = simple (log a line); multiple audits with data retention = complex (storage, rotation, export).

---

## How to Count BCP for a Story

### Step 1: Fill Out the Template

For each story, fill in all sections. If a section is empty (e.g., "Interface Elements: None"), that's data—it tells you that story has low UI complexity.

### Step 2: Count Each Dimension

| Dimension | How to Count |
|-----------|---|
| Business Rules | # of rules listed |
| Interface Elements | # of UI controls/components |
| Roles/Permissions | # of distinct permission sets |
| Solution Variabilities | # of configuration parameters |
| Domain Entities | Existing + New (from BCR matrix: count determines XS–XL) |
| Boundaries | # of cross-layer/cross-system integration points |
| Background Processes | # of async/scheduled processes |
| Notifications | # of distinct events emitted/received |
| Audits | # of distinct audit requirements |

### Step 3: Consult the BCR Matrix

The **Business Complexity Ruler** matrix maps these counts to complexity levels:

```
Example:
- Story with 2 entities, 1 rule, 0 UI elements = XS1
- Story with 5 entities, 4 rules, 2 UI elements, 2 processes = M3
- Story with 7+ entities, 5+ rules, 3+ processes = L5 or XL8
```

(See the visual BCR ruler at top of this doc; it defines the mapping precisely.)

### Step 4: Validate Against Acceptance Criteria

Does your estimated complexity match the story's acceptance criteria?

- 5 acceptance criteria = likely S or M.
- 1–2 acceptance criteria = likely XS.
- 8+ acceptance criteria = likely M or L.

If mismatch, re-examine the story; complexity may be hidden.

---

## Example: Story 2 Complexity Breakdown

**Story:** Lock-Dock-Position

**Dimension Counts:**
- Business Rules: 5
- Interface Elements: 1 (visual indicator)
- Roles/Permissions: 1 (Accessibility)
- Solution Variabilities: 3 (lock mode, retry count, retry delay)
- Domain Entities: 6 (config, monitorState, delta, lockState, attempt, failedEvent)
- Boundaries: 1 (Accessibility API)
- Background Processes: 2 (executor, retry handler)
- Notifications: 3 (LockAttempt, LockFailedEvent, VisualIndicator)
- Audits: 1 (every attempt)

**Complexity Assessment:**
- 6 entities → BCR matrix suggests L5 (6 is at the upper end of M/lower end of L).
- 5 business rules → moderate complexity.
- 2 background processes → async logic (increases complexity).
- 3 solution variabilities → branching logic.

**Estimated BCP:** L5 ✓

(This story has the most complex logic: retry handlers, visual feedback, cross-component messaging. It justifies the L5 rating.)

---

## How This Prevents Surprises

### Before (Generic User Story)
```
As a user, I want the Dock to stop jumping.
Acceptance: Dock doesn't move when I launch apps.
```

**Hidden Complexity:**
- Permissions? (not mentioned)
- What if lock fails? (not mentioned)
- Event logging for debugging? (not mentioned)
- Permission checks at runtime? (not mentioned)

**Result:** Developer estimates S, implements 50% of features, discovers M-level work.

---

### After (BCP-Aware Story)
```
Story: Lock-Dock-Position [L5]

Business Rules: 5 (permission gate, restore to previous, latency SLA, retry logic, visual feedback)
Domain Entities: 6 (config, monitorState, delta, lockState, attempt, failedEvent)
Processes: 2 (executor, retry handler)
Audits: 1 (every attempt)

Acceptance: 6 criteria (AC1–AC6)
Test Cases: 4 scenarios (happy path, retry success, retry failure, disabled)
```

**What's Visible:**
- Retry logic → async complexity.
- Visual indicator → UI coupling.
- Audit trail → logging complexity.
- Latency SLA (200ms) → performance requirement.

**Result:** Developer sees L5 complexity upfront. Estimates correctly. No surprises.

---

## Summary: Why BCP-Aware Stories Work

1. **Explicit Dimensions:** All 10 BCP dimensions are mapped to template sections. Nothing is hidden.

2. **Countable:** Each dimension is enumerated (# of rules, # of entities, etc.). No vague estimates like "complex."

3. **Structured for Models:** AI can parse sections, count dimensions, and aggregate complexity across stories.

4. **Aligned with bigpowers:** Spec-driven format + test-first mindset + explicit acceptance criteria.

5. **Prevents Scope Creep:** When you see "6 entities" and "2 background processes," you know this isn't a quick fix.

6. **Enables Prioritization:** Separate stories by BCP level. MVP = XS + S stories only. Later releases handle M + L stories.

7. **Improves Handoff:** Specs are machine-readable and human-reviewable. Domain experts can validate business rules; developers can implement with confidence.

---

## Next Steps

1. **Review Big DockLocker stories** (`BCP-STORIES.md`) with your team.
2. **Validate complexity levels** against your own experience. Are the L5/M3/S2 ratings reasonable?
3. **Use for implementation:** Each story is a TDD task. Acceptance criteria are pass/fail. Audit requirements are non-negotiable.
4. **Apply to other projects:** Once you master this template, every project becomes BCP-visible and countable.
