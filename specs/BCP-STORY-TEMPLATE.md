# BCP-Aware Specification Story Template

## Rationale

This template combines **specification-driven storytelling** (bigpowers) with **Business Complexity Ruler dimensions** to ensure:
- Every story explicitly maps to BCP dimensions
- Hidden complexity surfaces early (entities, permissions, processes)
- Models can count complexity accurately across all 10 dimensions
- Specs remain actionable and test-driven

---

## Template

```
# [VERB-NOUN]: [Short Title]

**BCP Level (Estimated):** XS | S | M | L | XL

## Business Objective
[1–2 sentences: What business need does this story fulfill?]

## Scope Boundaries
[What domain entities does this story touch? What's explicitly OUT of scope?]

---

## Business Rules
[Rules that MUST be enforced. These are non-negotiable.]
- Rule 1: [Consequence if violated]
- Rule 2: [Consequence if violated]

## Interface Elements
[UI/UX components, displays, inputs]
- Element 1: [Purpose and constraints]
- Element 2: [Purpose and constraints]

## Roles & Permissions
[Which roles/users can perform what? What are permission boundaries?]
- Role 1: [Permissions and constraints]
- Role 2: [Permissions and constraints]

## Solution Variabilities
[How does behavior change based on configuration or parameters?]
- Variability 1: [How behavior changes]
- Variability 2: [How behavior changes]

## Domain Entities
[Entities created, modified, or read in this story]

### Existing Entities (Count: _)
- Entity 1: [Role in story]
- Entity 2: [Role in story]

### New Domain Entities (Count: _)
- Entity 3: [Purpose, attributes, relationships]

## Boundaries & Entity Interactions
[Cross-system or cross-layer boundaries affected?]
- Boundary 1: [Which entities, data exchange, durability concerns]

## Background Processes
[Async, scheduled, or triggered processes]
- Process 1: [Trigger, frequency, outcome]

## Notifications & Events
[Events sent to users or other systems]
- Notification 1: [Trigger, audience, content]

## Audits
[Audit trail requirements for compliance or forensics]
- Audit 1: [What to log, retention, sensitivity]

---

## Acceptance Criteria

- [ ] **AC1:** [Specific, measurable condition]
- [ ] **AC2:** [Specific, measurable condition]
- [ ] **AC3:** [Specific, measurable condition]

## Test Cases (TDD Style)

### Given-When-Then (Happy Path)
```gherkin
Given [Initial state]
 When [User action]
 Then [Expected outcome]
```

### Edge Cases
```gherkin
Given [Edge condition]
 When [Unusual action]
 Then [Graceful handling]
```

---

## Complexity Summary

| Dimension | Count | Notes |
|-----------|-------|-------|
| Business Rules | _ | [Rules listed above] |
| Interface Elements | _ | [UI components] |
| Roles/Permissions | _ | [Permission sets] |
| Solution Variabilities | _ | [Parameter-driven behavior] |
| Domain Entities | _ | Existing: _; New: _ |
| Boundaries | _ | [Cross-system interactions] |
| Background Processes | _ | [Async work] |
| Notifications | _ | [Events sent] |
| Audits | _ | [Audit trails] |
| **Total BCP** | **?** | Consult BCR matrix |

---

## Definition of Done

- [ ] Spec reviewed and complexity agreed with team
- [ ] Test cases written (TDD)
- [ ] Code implements all business rules
- [ ] All acceptance criteria pass
- [ ] Audit/notification code complete (if applicable)
- [ ] No hardcoded values; all variabilities parameterized
```

---

## Why This Works

1. **Forces explicit thinking** about all 10 BCP dimensions—nothing is hidden.
2. **Makes counting precise**—entities, rules, processes are enumerated, not vague.
3. **Aligns with bigpowers** spec-driven, test-first philosophy.
4. **Scalable for models** — each section is structured data, easy for Claude to parse and count.
5. **Reveals scope creep early** — when you map a "simple feature" and see 5 new entities + 3 permission sets, complexity is obvious.

---

## Next: Big DockLocker Stories

See `BCP-STORIES.md` for the complete app decomposed into BCP-aware stories.
