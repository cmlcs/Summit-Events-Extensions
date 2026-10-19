# Amsterdam Sprint — Proposed User Stories

**Epic:** EPIC-01 — Targeted Invitation Management for Summit Events  
**Scenario:** Annual nonprofit gala, 600 invitees including major donors and ambassadors  
**Status:** Draft for team refinement. Story IDs, priorities and implementation are not yet confirmed against a Sprint board.

## Cross-cutting requirements

- Support eligible Contact and Lead Campaign Members without exposing sensitive personal data.
- Avoid duplicate Registrations under retries and bulk processing.
- Preserve existing public registration behavior and payment/appointment paths.
- Enforce permissions and secure public responses.
- Provide test coverage, user guidance and implementation notes.
- Verify exact Salesforce metadata and registration statuses before committing to a design.

## US-01 — Associate a Campaign with an Event Instance

**As an** Event Manager, **I want** to associate a Salesforce Campaign with a Summit Event Instance, **so that** I can manage a targeted invitation audience for that occurrence.

**Acceptance criteria**
1. Authorized users can identify a Campaign as belonging to an Event Instance.
2. The relationship is visible and usable in the Event Manager workflow.
3. Validation prevents unsupported or ambiguous associations according to the agreed cardinality.
4. Existing Campaigns unrelated to Summit Events are unaffected.

**Dependencies / decisions:** Campaign-to-instance cardinality, metadata approach, permissions.  
**Suggested priority:** P0.

## US-02 — Manage the invitation audience

**As an** Event Manager, **I want** to select Contacts and Leads as Campaign Members, **so that** I can define the 600-person gala invitation audience.

**Acceptance criteria**
1. The manager can use standard Campaign Member mechanisms to build the audience.
2. Contacts and Leads are supported according to agreed eligibility rules.
3. Existing membership duplicates are not created by the enhancement.
4. Staff can identify the intended audience and member invitation state.
5. Removing or changing membership follows a documented policy.

**Dependencies / decisions:** Campaign Member status model, handling removed members, selection tools.  
**Suggested priority:** P0.

## US-03 — Create an invitation-stage Registration

**As an** Event Manager, **I want** a Summit Event Registration created or associated when an eligible Campaign Member joins an event Campaign, **so that** I can track an invitation before the person registers.

**Acceptance criteria**
1. Only Campaign Members of linked Event Campaigns trigger the behavior.
2. The correct Event Instance and Contact or Lead are associated with the Registration.
3. The Registration receives the agreed invitation-stage status (proposed label: `Invited`, subject to metadata verification).
4. Reprocessing the same Campaign Member does not create a duplicate Registration.
5. Bulk addition of 600 members is handled safely within Salesforce limits.
6. Errors are surfaced or logged and are testable.

**Dependencies / decisions:** Registration object capabilities, matching key, Flow vs Apex, bulk and failure handling.  
**Suggested priority:** P0.

## US-04 — Prepare personalized invitations

**As an** Event Manager, **I want** to generate invitations containing event details and a recipient-specific link, **so that** invitees can respond without re-entering identifying information unnecessarily.

**Acceptance criteria**
1. An approved email template can include required event information and an invitation link.
2. Each link resolves to the intended invitation context without revealing internal identifiers as authentication secrets.
3. Invalid, expired, revoked or reused links are handled safely under an agreed policy.
4. The solution documents how invitations are sent and any org/email limits.
5. Templates can be reviewed without sending real emails.

**Dependencies / decisions:** Email tooling, merge-field strategy, secure token lifecycle, sender and delivery ownership.  
**Suggested priority:** P1.

## US-05 — Accept an invitation through registration

**As an** Invitee, **I want** to use my invitation link to register for the gala, **so that** my response updates the existing invitation record.

**Acceptance criteria**
1. A valid invitation link leads to the supported registration experience.
2. Completing registration updates the intended existing Registration rather than creating a duplicate.
3. Existing registration questions, appointments, fees and confirmations continue to work where configured.
4. Errors and already-completed invitations have clear behavior.
5. Both applicable public UI paths are assessed for regressions.

**Dependencies / decisions:** Registration UI entry point, session/cookie behavior, status transitions.  
**Suggested priority:** P1.

## US-06 — Decline an invitation

**As an** Invitee, **I want** to decline an invitation, **so that** the organization knows I cannot attend.

**Acceptance criteria**
1. A valid invitee can explicitly decline through an approved public experience.
2. The intended Registration is updated to an agreed decline state (proposed label: `Declined`).
3. An optional decline reason is stored only if approved and appropriately protected.
4. A person cannot decline another invitee's registration by changing a URL parameter.
5. Repeat declines and declines after registration follow documented rules.

**Dependencies / decisions:** Separate page vs registration-page option, token validation, privacy and status rules.  
**Suggested priority:** P1.

## US-07 — Monitor invitation responses

**As an** Event Manager, **I want** to see who has been invited, registered, or declined, **so that** I can manage gala attendance and follow-up.

**Acceptance criteria**
1. Staff can view response status for the Event Instance's invitation audience.
2. Counts and lists distinguish invited, registered and declined states as defined by the team.
3. Status reconciliation between Campaign Members and Registrations follows an explicit source-of-truth rule.
4. Staff can identify nonrespondents for follow-up.
5. The display respects Salesforce sharing and permissions.

**Dependencies / decisions:** Status synchronization, report vs record-page component, multiple Campaigns per Event Instance.  
**Suggested priority:** P1.

## Suggested testing scenarios

| ID | Scenario | Expected result |
| --- | --- | --- |
| T01 | Add one Contact to an event Campaign | One correctly linked invitation-stage Registration |
| T02 | Add one Lead | Supported or clearly rejected according to approved design |
| T03 | Add 600 Campaign Members | No limit failures; correct records; no duplicates |
| T04 | Reprocess a member | Idempotent result |
| T05 | Add member to ordinary Campaign | No Summit Events side effect |
| T06 | Use valid personalized invitation | Correct existing Registration is updated |
| T07 | Use invalid/expired link | Safe, informative failure; no record exposure |
| T08 | Decline invitation | Correct state and optional reason |
| T09 | Attempt to alter another invitee's response | Blocked |
| T10 | Complete existing public registration path | No regression |

## Definition of done (proposed)

A story is done when its acceptance criteria are demonstrated, relevant automated tests pass, security and bulk behavior are considered, documentation is updated, and a PR has been reviewed and accepted under the team's process. A demo alone does not imply production readiness.

## Source and scope note

US-01 through US-07 expand the supplied invitation-processing enhancement request into implementable slices. The request did not specify these IDs or exact acceptance criteria. Confirm all stories with project maintainers before treating them as committed scope.
