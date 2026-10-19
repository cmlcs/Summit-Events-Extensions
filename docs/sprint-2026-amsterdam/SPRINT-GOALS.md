# Amsterdam Community Sprint — Goals and Outcomes

**Dates:** 19–20 October 2026  
**Application:** Summit Events App  
**Theme:** Invitation processing and Salesforce Campaign integration

## Scenario: the annual gala

A nonprofit is preparing its annual fundraising gala. It intends to invite **600 people**, including major donors, ambassadors, and other stakeholders. Staff maintain relationships in Salesforce and use Summit Events to manage the event. They need to select invitees, send personalized invitations, receive responses, and monitor progress without maintaining disconnected lists.

The 600-person gala is a **test scenario**, not a claim about existing sample data or confirmed system capacity.

## Problem

The enhancement request describes Summit Events as providing a registration link suitable for broadcast invitations, but lacking an integrated process for selecting specific Contacts/Leads and tracking targeted invitations via Campaigns. The request proposes connecting Campaigns, Campaign Members, Event Instances, and Registrations.

## Desired outcome

Design and, within the time available, implement and validate a coherent **targeted invitation workflow** for Summit Events using standard Salesforce Campaign capabilities wherever practical.

### Target journey (proposed, not existing behavior)

1. Configure a Summit Event and an Event Instance.
2. Create or designate a Salesforce Campaign for that Event Instance.
3. Add selected Contacts and Leads as Campaign Members.
4. Create or associate an invitation-stage Summit Event Registration for each eligible member.
5. Prepare an invitation with event details and a personalized registration link.
6. Allow invitees to register or explicitly decline.
7. Track responses from the Event Instance and, where appropriate, the Campaign.

## Priorities

| Priority | Candidate deliverable | Notes |
| --- | --- | --- |
| P0 | Confirm current data model, status values, security model, and integration seams | Required before development |
| P0 | Campaign ↔ Event Instance association | Design and implement if feasible |
| P0 | Campaign Member → invitation registration | Bulk-safe and idempotent |
| P0 | Automated tests and concise documentation | Required for merged work |
| P1 | Personalized invitation URL and registration reuse | Requires security design and existing-flow investigation |
| P1 | Decline path and response tracking | Requires guest-user and status design |
| P1 | Invitation email template and event merge data | Check actual template capabilities |
| P2 | Advanced marketing-platform integrations | Future-compatible architecture, not a dependency for MVP |

These are **suggested priorities**, not decisions already accepted by the team.

## Workstreams and participant learning

- **Functional design:** Campaign strategy, event lifecycle, personas, acceptance criteria.
- **Admin / automation:** Campaign configuration, Salesforce Flow, data integrity, permissions.
- **Development:** Apex, LWC/Visualforce touchpoints, secure links, testing.
- **DevOps:** GitHub issues, branches, pull requests, reviews, deployment and CI.
- **Quality / documentation:** Test cases, accessibility, diagrams, screenshots, user-facing guidance and AI-readable documentation.
- **Optional discovery:** Marketing Cloud / Agentforce Marketing / Salesforce Foundations integration possibilities; avoid assuming licensing or available features.

## Success criteria for the two days

- Each active story has an agreed owner, acceptance criteria, and disposition: delivered, partially delivered, or deferred.
- Changes are traceable to GitHub branches/PRs and are reviewed and tested.
- The 600-invitee scenario has an executable test plan, including bulk behavior, duplicates, Contacts vs Leads, declines, and guest access.
- Architectural decisions and unresolved questions are captured.
- Documentation allows another contributor to continue after the Sprint.

## Out of scope unless explicitly approved

- A complete replacement for Salesforce marketing products.
- A production email-delivery service or guaranteed deliverability solution.
- Unreviewed changes to the public registration flow.
- Importing real donor records into personal AI tools.

## Source and interpretation

The targeted-invitation problem and proposed Campaign integration come from the supplied enhancement request. The previous Sprint plan covered LWC parity testing, PR/bug work, and documentation review; those are **historical context**, not automatically the Amsterdam Sprint's workstreams. The gala scenario and priorities above are Amsterdam planning proposals.
