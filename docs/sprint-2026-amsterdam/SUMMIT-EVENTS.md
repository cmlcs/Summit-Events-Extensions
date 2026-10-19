# Summit Events App — Shared Technical Context

## Purpose

Summit Events App (SEA) is a community-built Salesforce event-management solution for nonprofit and education use cases. The August 2026 Community Sprint deck describes configurable registration forms, event templates, Contact/Lead connections, payment data, and confirmation communications.

**Canonical code:** https://github.com/SFDO-Community/Summit-Events-App

> This document is a source-grounded orientation, **not** a current-code audit. Confirm every technical name, relationship, and behavior in the checked-out repository and a development org.

## Relevant concepts

| Concept | Role in this enhancement | Verification needed |
| --- | --- | --- |
| Summit Event | Event definition / configuration | Exact API name and relationship to instances |
| Summit Event Instance | Specific event occurrence; proposed Campaign link | Exact API name, lookup direction and record page |
| Summit Event Registration | Registration and proposed invitation-response record | Exact API name, Contact/Lead handling, allowed statuses |
| Campaign | Standard Salesforce audience/campaign record | How to link to an Event Instance; constraints |
| Campaign Member | Standard membership of a Contact or Lead in a Campaign | Triggers/Flows, statuses, deduplication and lifecycle |
| Questions / Appointments / Fees | Existing registration journey components | Impact of pre-created registrations and personalized links |

## Existing experience described in prior Sprint material

The previous Sprint plan identified a registration sequence that may include:

1. Registration details
2. Additional questions
3. Guest registration
4. Appointments / sessions
5. Donations / fees
6. Submission
7. Confirmation

That plan also described both a legacy Visualforce/Sites experience and an Experience Cloud/LWC experience, with parity testing as an earlier goal. **Check the current branch** before assuming either experience has the same behavior today.

## Enhancement request: proposed behavior

The request proposes:

- Flagging or associating a Campaign with a Summit Event Instance.
- Creating a Registration in an **Invited** state when a relevant Campaign Member is added.
- Supporting invitation email templates with event details and a registration link.
- Providing an individualized link to reconnect a public response to the existing registration.
- Supporting an explicit decline, potentially with a separate public page and optional reason.
- Displaying invitation/response progress from the Event Instance.

These are **requirements and ideas**, not verified existing features. The example field names and Flow design in the request are suggestions, not authoritative metadata.

## Technical investigation before implementation

### Data model

- Identify exact object/field API names, lookup/master-detail relationships, status picklists, validation rules, and managed-package/namespace considerations.
- Determine whether a Registration can exist before completion and whether it can reference a Lead, Contact, or both.
- Determine whether existing records can be matched safely without duplicating registrations.

### Execution and automation

- Find existing triggers, handlers, record-triggered Flows, and registration creation services.
- Check bulk insert/update behavior, reprocessing, deletion, and transaction failures.
- Confirm whether standard Campaign Member status changes should be synchronized and how conflicts are resolved.

### Public registration and security

- Trace the actual public entry points and registration state transitions.
- Design opaque, unguessable, expiring/revocable invitation tokens if personalized links are implemented; do not expose Salesforce IDs as authentication.
- Validate guest-user access, least privilege, data leakage, link forwarding, replay behavior, and CSRF protections where relevant.
- Ensure a decline action cannot modify another person's registration.

### Emails and marketing

- Inspect available email templates, merge-field limitations, automation, and org-level sending limits before choosing a design.
- Keep Marketing Cloud integrations optional and loosely coupled.

### Testing

- Test Contact and Lead members, 600-member batches, repeat automation, invalid or removed members, registration completion, decline, permissions, and both relevant registration UIs.
- Test existing functionality for regressions.

## Source references

- [Repository](https://github.com/SFDO-Community/Summit-Events-App)
- [Invitation processing proposal](https://trailhead.salesforce.com/trailblazer-community/feed/0D5KX00000pNKtJ0AW)
- Supplied `Previous-Sprint-Plan.txt` and August 2026 KBYG deck (pages 12 and 41).

## Confidence labels for AI use

- **Verified from supplied documents:** broad purpose, historical registration sequence, and requested enhancement.
- **Proposed:** Campaign association, invited registrations, personalized links, decline page, dashboards.
- **Unverified:** current API names, implementation classes, available picklist values, existing package behavior, and chosen technical architecture.
