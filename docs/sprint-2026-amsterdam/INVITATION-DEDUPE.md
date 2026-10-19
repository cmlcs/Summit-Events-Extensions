# Invitation deduplication — how to call it

**Story:** Sprint board US-05 "Prevent duplicate Gala registrations" (context pack US-03, criterion 4)
**Code:** `InvitationRegistrationDedupe` (branch `feature/us05-registration-dedupe`, deployed to the SummitEvents sandbox)
**For:** the Campaign Member → Registration batch job (US-03)

The service guarantees **one Registration per person per Event Instance**. The person is the Contact, or the Lead when there is no Contact. The guarantee comes from the unique External ID field `Invitation_Key__c` on `summit__Summit_Events_Registration__c` (`<EventInstanceId>:<ContactId or LeadId>`), so it holds even when runs overlap or are retried.

## Calls per `execute()` chunk, in order

1. **`new InvitationRegistrationDedupe.Request(eventInstanceId, contactId, leadId, campaignMemberId)`**, once per Campaign Member.
   Only builds the input; nothing is queried or saved. Pass both `ContactId` and `LeadId` when the member has both (after Lead conversion): the Contact wins, and the Lead is used to find older Registrations. The Campaign Member Id is required.

2. **`InvitationRegistrationDedupe.resolve(requests)`**, once per chunk.
   Finds existing Registrations for all requests in one query. Existing Registrations without a key (for example from the public form) are adopted: only `Invitation_Key__c` is filled in, and Status, answers and other fields are never changed. Returns `Map<CampaignMemberId, Result>` with one result per member:

   | Outcome | Meaning | What the job does |
   | --- | --- | --- |
   | `EXISTING_FOUND` | Person already has a Registration (`result.registration`) | Apply DEC-007 (link the Campaign Member or reject it) |
   | `NEW_REGISTRATION_NEEDED` | No Registration yet | Build one (step 3) |
   | `DUPLICATE_IN_REQUEST` | Same person through another member in this chunk | Skip |
   | `SKIPPED_NO_PERSON` | No Contact or Lead | Log |
   | `FAILED` | Adopting failed, see `result.message` | Log |

3. **`InvitationRegistrationDedupe.insertRegistrations(Map<CampaignMemberId, Registration>)`**, once per chunk, with only the `NEW_REGISTRATION_NEEDED` members.
   Sets the key and inserts with partial success, so one bad row does not stop the rest. Returns `Map<CampaignMemberId, Result>`:

   | Outcome | Meaning | What the job does |
   | --- | --- | --- |
   | `CREATED` | Inserted | Done |
   | `EXISTING_FOUND` | Another run inserted this person a moment earlier; the existing Registration is returned | Apply DEC-007 |
   | `FAILED` | Other error, see `result.message` | Log |

Do not call these yourself: `findExisting` and `adoptExisting` are the two halves of `resolve` (`findExisting` alone is fine for a read-only preview), and `buildKey` is used internally.

## Rules for the batch job

- **Set `summit__Event_Instance__c`, `summit__Event__c`, and `summit__Contact__c` or `summit__Lead__c`** on every new Registration. Without the person, SEA's trigger runs contact matching record by record, which is slow and expensive at 200 per chunk. The person is also what the key is built from.
- **Don't throw in `execute()`.** An exception rolls back the whole chunk. Duplicates come back as outcomes, not exceptions. `InvitationProcessingException` is only thrown for programming errors: a request without an Event Instance, or a missing or repeated Campaign Member Id.
- **Choose the Registration status carefully (DEC-003).** SEA sends an email right after insert when `summit__Registrant_Email__c` is filled and the status matches one of the event's email templates. The sandbox sample templates fire on "Registered". The sandbox is a Full copy with real-looking Contacts, so use synthetic Contacts for tests.
- **Re-runs and parallel jobs are safe.** A person handled in an earlier chunk or run returns `EXISTING_FOUND`.
- **Use `Database.Stateful`** if you want outcome totals in `finish()`.

## Permissions and dependencies

- The service runs `without sharing` and in system mode, so it sees every Registration regardless of the running user. Call it only from trusted automation, never from guest-facing code.
- The running user needs SEA's **Summit Events Admin** permission set. SEA's own Registration trigger throws a NullPointerException for users who cannot read `Summit_Events__c` (an SEA bug, to be reported upstream).
- `Summit_Events_Invitation_Admin` gives read-only access to `Invitation_Key__c`. The service does not need it.
- Campaign → Event Instance mapping: Jelena's unmanaged `Campaign__c` lookup on Event Instance (DEC-001, not yet in this repo).
- What happens to the Campaign Member on `EXISTING_FOUND`: DEC-007 (Proposed).

## Tests

`InvitationRegistrationDedupeTest`: 13 tests, including reprocessing 600 invitees, adopting a public-form Registration without changing it, blank-person handling, same person twice in one insert, and an Event Manager without access to the key field. Passed in the SummitEvents sandbox on 2026-10-19 (runs `707di0000LD89iF`, `707di0000LD8BAX`).
