# Campaign Member status sync: US-10

Status: **proposed**, for team review. See DEC-003.

## Behavior

1. **Campaign statuses.** When a Campaign is created with, or later given, a **Summit Events Instance**, the flow `Campaign_Add_Registration_Statuses` adds each active value of the Registration picklist `summit__Status__c` as a Campaign Member Status. Values are read at run time from the picklist describe, so they are not hard-coded.
2. **Member status.** When a Registration with a `Campaign_Member_Id__c` is created, changes status, or gets linked to a Campaign Member, the flow `Registration_Sync_Campaign_Member_Status` sets that member's **Status** to the Registration status.
3. **New picklist values.** If a Registration gets a status that the Campaign does not have yet, for example a value added to the picklist after the Campaign was linked, the missing statuses are added before the member is updated.

The Registration is the source of truth. The sync runs one way only: a Campaign Member status edited by hand is overwritten at the Registration's next status change and is never copied back to the Registration.

## Components

| Component | Purpose |
| --- | --- |
| Flow `Campaign_Add_Registration_Statuses` | Record-triggered (after save) on Campaign. Entry: Instance is set and the record is new or the Instance changed. |
| Flow `Registration_Sync_Campaign_Member_Status` | Record-triggered (after save) on Registration. Entry: `Campaign_Member_Id__c` is set and the record is new, or its status or Campaign Member changed. |
| Apex `AddRegistrationStatusesToCampaign`, `SyncCampaignMemberStatus` | Invocable actions called by the flows. |
| Apex `CampaignMemberStatusSync` | Shared logic. Flow cannot read picklist values dynamically, so this part is in Apex. |

Manifest: `manifest/us-10.xml`.

## Rules

- Existing Campaign Member Statuses are never changed or deleted. The Campaign's default status (usually *Sent*) stays as it is.
- New statuses are added after the Campaign's existing ones. **Responded** is checked for every status except `Invited`, `Started` and `In Progress`.
- Labels are matched case-insensitively, so a Campaign that already has *invited* does not get a second *Invited* status.
- Bulk-safe: each flow batch uses a fixed number of queries and DML statements, and the tests cover 600 members.
- Runs in system mode without sharing, because Registration saves come from the public site's guest user. Failures are logged with `System.debug` and never block the Campaign or Registration save.
- Registrations without a Campaign Member, or linked to a Campaign Member that has been deleted, are skipped.

## Interaction with invitation processing

- When a member's status changes to `Invited`, the `CampaignMember` trigger enqueues `SummitInvitationQueueable`. The sync sets `Invited` only when the Registration itself is `Invited`. The queueable then finds that Registration and changes nothing.
- When `InvitationRegistrationDedupe` links an existing Registration (for example, one that is already *Registered*) to a new member, the member immediately takes the Registration's status.

## Open questions

- Which statuses should count as **Responded**? (Proposed: everything except Invited, Started and In Progress.)
- `Campaign_Member_Id__c` is not unique. If one member is linked to several Registrations, the most recent status change wins. Is that acceptable?
- Should `Invited` become the Campaign's default status? That would make **Add to Campaign** create Registrations straight away, so it is deliberately not done.
- Should statuses be removed from Campaigns when a picklist value is deactivated? Currently they are not.
