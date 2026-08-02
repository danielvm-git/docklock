# Big DockLocker: BCP-Aware Specifications

This folder contains Big DockLocker's complete specification using a **BCP-aware story template** designed to make business complexity countable and transparent.

## Documents

### 1. **BCP-STORY-TEMPLATE.md**
The core story template. Use this as your template for any new story.

- Why this template works (forces explicit thinking about all 10 BCP dimensions)
- Complete story template structure
- How each section maps to BCP dimensions
- Definition of Done checklist

### 2. **BCP-STORIES.md**
Complete Big DockLocker app specification in 7 stories.

**Stories:**
1. **Monitor-Dock-Events** [M3] — Background Accessibility monitoring for Dock position changes
2. **Lock-Dock-Position** [L5] — Prevent Dock from jumping (retry logic, visual feedback)
3. **Configure-Lock-Behavior** [M3] — Dashboard settings (toggles, sliders, persistence)
4. **Display-Lock-Status** [S2] — Real-time status display and event log
5. **Handle-System-Permissions** [S2] — Accessibility permission lifecycle management
6. **Log-Anti-Jump-Events** [M3] — Audit trail, file rotation, export
7. **Recover-From-Permission-Loss** [S2] — Graceful degradation on permission revocation

Each story includes:
- Business objective
- Business rules (explicit, numbered)
- Interface elements (all UI listed)
- Roles & permissions
- Solution variabilities (configuration parameters)
- Domain entities (existing + new)
- Boundaries & entity interactions
- Background processes (async logic)
- Notifications & events (messaging points)
- Audits (compliance/forensics)
- Acceptance criteria (testable)
- Test cases (TDD-style Given/When/Then)
- Complexity summary table

### 3. **BCP-METHODOLOGY.md**
Why this template works and how to use it for accurate complexity counting.

- The problem (standard agile formats miss business structure)
- The solution (BCP-aware specifications)
- Detailed walkthrough of each dimension (with examples)
- How to count BCP for a story
- How to consult the BCR matrix
- Example breakdown (Story 2: Lock-Dock-Position [L5])
- How this prevents scope creep and surprises

## Quick Start

### For Developers (TDD)
1. Pick a story from BCP-STORIES.md
2. Read its **Acceptance Criteria** and **Test Cases**
3. Write tests first (test-first discipline)
4. Implement code to make tests pass
5. Verify all **Acceptance Criteria** pass
6. Verify **Audit** requirements are implemented
7. Mark story done

### For Teams / Code Review
1. Validate story **Complexity Assessment** is accurate
2. Verify all **Business Rules** are clearly listed
3. Check that **Domain Entities** are complete
4. Ensure **Background Processes** are documented
5. Confirm **Audit** requirements are implemented

### For PMs / Prioritization
1. Review **BCP Level** for each story
2. MVP = XS + S stories only
3. Release 1 = add M stories
4. Release 2 = add L stories

## Complexity Summary

| Story | Level | Entities | Rules | Processes |
|-------|-------|---|---|---|
| 1. Monitor-Dock-Events | M3 | 3 | 4 | 2 |
| 2. Lock-Dock-Position | L5 | 6 | 5 | 2 |
| 3. Configure-Lock-Behavior | M3 | 3 | 4 | 1 |
| 4. Display-Lock-Status | S2 | 5 | 4 | 2 |
| 5. Handle-System-Permissions | S2 | 3 | 4 | 1 |
| 6. Log-Anti-Jump-Events | M3 | 7 | 5 | 2 |
| 7. Recover-From-Permission-Loss | S2 | 4 | 5 | 0 |
| **TOTAL** | **~L avg M** | **31** | **31** | **10** |

---

**Created:** May 22, 2026  
**Project:** Big DockLocker
