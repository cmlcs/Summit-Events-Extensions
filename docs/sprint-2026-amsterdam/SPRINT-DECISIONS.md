# Amsterdam Sprint — Decision Log

**Dates:** 19–20 October 2026  
**Purpose:** Maintain a shared, human-approved record of architecture and scope decisions.  
**Rule:** Only the team/maintainers can accept a decision. AI suggestions are not decisions.

## Status definitions

- **Proposed:** Under discussion, not binding.
- **Accepted:** Confirmed by the responsible team/maintainer.
- **Superseded:** Replaced by a later decision.
- **Deferred:** Not being decided during this Sprint.

## Decisions

No architectural decisions are recorded as accepted in this initial pack.

### DEC-001 — Campaign to Event Instance relationship

- **Date:** 2026-10-19
- **Status:** Proposed
- **Question:** Can an Event Instance be linked to one or multiple Campaigns? What is the lookup direction and how is it exposed to admins?
- **Options:** Campaign lookup to Event Instance; junction model; another pattern after metadata review.
- **Decision:** Pending team review.
- **Rationale:** Pending.
- **Affected stories:** US-01, US-02, US-07.
- **Owner / approver:** TBD.

### DEC-002 — Registration creation automation

- **Date:** 2026-10-19
- **Status:** Proposed
- **Question:** Flow or Apex for Campaign Member → Registration creation, and what makes processing idempotent?
- **Decision:** Pending repository and data-model investigation.
- **Affected stories:** US-02, US-03.
- **Owner / approver:** TBD.

### DEC-003 — Invitation and registration statuses

- **Date:** 2026-10-19
- **Status:** Proposed
- **Question:** Can existing Registration statuses represent `Invited` and `Declined`, and which system owns Campaign Member status synchronization?
- **Decision:** Pending verification of picklists and current behavior.
- **Affected stories:** US-03, US-05, US-06, US-07.
- **Owner / approver:** TBD.

### DEC-004 — Personalized invitation links

- **Date:** 2026-10-19
- **Status:** Proposed
- **Question:** How are invitees securely associated with an existing Registration, including token expiry, revocation, replay and forwarded links?
- **Decision:** Pending security design.
- **Affected stories:** US-04, US-05, US-06.
- **Owner / approver:** TBD.

### DEC-005 — Decline experience

- **Date:** 2026-10-19
- **Status:** Proposed
- **Question:** Should decline be a dedicated public page or an option in the existing registration experience? Is a reason collected?
- **Decision:** Pending UX and guest-security review.
- **Affected stories:** US-06.
- **Owner / approver:** TBD.

### DEC-006 — Invitation email delivery

- **Date:** 2026-10-19
- **Status:** Proposed
- **Question:** What Salesforce-native email capabilities are in scope for MVP, and what integration boundary should support future marketing products?
- **Decision:** Pending feature/licensing review.
- **Affected stories:** US-04.
- **Owner / approver:** TBD.

## How to add a decision

Copy the template below and assign the next ID. Include links to the related GitHub issue, PR, Slack discussion, or meeting notes when available.

```markdown
### DEC-007 — [Title]

- **Date:** YYYY-MM-DD
- **Status:** Proposed / Accepted / Superseded / Deferred
- **Question:** [Decision to make]
- **Options considered:** [Alternatives]
- **Decision:** [Explicit choice]
- **Rationale:** [Why]
- **Consequences / risks:** [Tradeoffs]
- **Affected stories:** [IDs]
- **Owner / approver:** [Name or role]
- **Evidence:** [Links]
```

## Change protocol

When a decision becomes **Accepted**, update this file, link the relevant work item, and announce it to the team. Participants should refresh the file in their AI assistant. Never infer approval from a generated answer.
