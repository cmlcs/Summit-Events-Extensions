/**
 * Keeps Campaign Member statuses in line with Summit Events Registration statuses (US-10).
 *
 * - A Campaign linked to an Event Instance gets one Campaign Member Status per active summit__Status__c value.
 *   The values come from the picklist describe, so values added to the picklist later are picked up too.
 * - A Registration linked to a Campaign Member (Campaign_Member_Id__c) copies its status to that member. The
 *   Registration is the source of truth. A status the Campaign does not have yet is added first.
 *
 * Existing Campaign Member Statuses are never changed or removed, and the Campaign's default status is left alone.
 * Registration saves come from guest users on the public site, so this runs without sharing and in system mode.
 * Failed rows are logged and never block the Campaign or Registration save.
 */
public without sharing class CampaignMemberStatusSync {

    // Registration statuses that do not count as a response on the Campaign (HasResponded = false)
    @TestVisible
    private static final Set<String> NOT_RESPONDED_STATUSES = new Set<String>{ 'Invited', 'Started', 'In Progress' };

    /**
     * Active values of summit__Status__c, in picklist order.
     */
    public static List<String> registrationStatuses() {
        List<String> statuses = new List<String>();
        for (Schema.PicklistEntry entry : summit__Summit_Events_Registration__c.summit__Status__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                statuses.add(entry.getValue());
            }
        }
        return statuses;
    }

    /**
     * Adds every missing Registration status to the Campaigns that are linked to an Event Instance.
     * Other Campaigns are skipped. Safe to re-run.
     */
    public static void addRegistrationStatuses(Set<Id> campaignIds) {
        campaignIds = new Set<Id>(campaignIds);
        campaignIds.remove(null);
        if (campaignIds.isEmpty()) {
            return;
        }

        Set<String> statuses = new Set<String>(registrationStatuses());
        Map<Id, Set<String>> statusesByCampaign = new Map<Id, Set<String>>();
        for (Campaign campaign : [
            SELECT Id
            FROM Campaign
            WHERE Id IN :campaignIds AND Summit_Events_Instance__c != NULL
            WITH SYSTEM_MODE
        ]) {
            statusesByCampaign.put(campaign.Id, statuses);
        }
        ensureStatuses(statusesByCampaign);
    }

    /**
     * Sets the Status of each linked Campaign Member to its Registration's status. Registrations without a
     * Campaign Member, or whose Campaign Member no longer exists, are skipped. Members that already have the
     * status are not updated.
     *
     * Campaign_Member_Id__c is not unique. When several Registrations in one call point at the same member,
     * the last one wins.
     */
    public static void syncFromRegistrations(Set<Id> registrationIds) {
        registrationIds = new Set<Id>(registrationIds);
        registrationIds.remove(null);
        if (registrationIds.isEmpty()) {
            return;
        }

        Map<Id, String> statusByMember = new Map<Id, String>();
        for (summit__Summit_Events_Registration__c registration : [
            SELECT Id, summit__Status__c, Campaign_Member_Id__c
            FROM summit__Summit_Events_Registration__c
            WHERE Id IN :registrationIds AND Campaign_Member_Id__c != NULL
            WITH SYSTEM_MODE
        ]) {
            Id memberId = toCampaignMemberId(registration.Campaign_Member_Id__c);
            if (memberId != null && String.isNotBlank(registration.summit__Status__c)) {
                statusByMember.put(memberId, registration.summit__Status__c);
            }
        }
        if (statusByMember.isEmpty()) {
            return;
        }

        List<CampaignMember> members = [
            SELECT Id, CampaignId, Status
            FROM CampaignMember
            WHERE Id IN :statusByMember.keySet()
            WITH SYSTEM_MODE
        ];

        // Make sure every Campaign has the statuses it is about to receive, plus any other missing Registration status
        Set<String> allStatuses = new Set<String>(registrationStatuses());
        Map<Id, Set<String>> statusesByCampaign = new Map<Id, Set<String>>();
        List<CampaignMember> membersToUpdate = new List<CampaignMember>();
        for (CampaignMember member : members) {
            String status = statusByMember.get(member.Id);
            if (member.Status == status) {
                continue;
            }
            if (!statusesByCampaign.containsKey(member.CampaignId)) {
                statusesByCampaign.put(member.CampaignId, new Set<String>(allStatuses));
            }
            statusesByCampaign.get(member.CampaignId).add(status);
            membersToUpdate.add(new CampaignMember(Id = member.Id, Status = status));
        }
        if (membersToUpdate.isEmpty()) {
            return;
        }

        ensureStatuses(statusesByCampaign);
        logFailures('CAMPAIGN MEMBER STATUS UPDATE', Database.update(membersToUpdate, false, AccessLevel.SYSTEM_MODE));
    }

    /**
     * Inserts the statuses each Campaign is missing (case-insensitive label match), after its highest SortOrder.
     */
    private static void ensureStatuses(Map<Id, Set<String>> statusesByCampaign) {
        if (statusesByCampaign.isEmpty()) {
            return;
        }

        Set<Id> campaignIds = statusesByCampaign.keySet();
        Map<Id, Set<String>> existingByCampaign = new Map<Id, Set<String>>();
        Map<Id, Integer> maxSortOrderByCampaign = new Map<Id, Integer>();
        for (CampaignMemberStatus existing : [
            SELECT CampaignId, Label, SortOrder
            FROM CampaignMemberStatus
            WHERE CampaignId IN :campaignIds
            WITH SYSTEM_MODE
        ]) {
            if (!existingByCampaign.containsKey(existing.CampaignId)) {
                existingByCampaign.put(existing.CampaignId, new Set<String>());
            }
            existingByCampaign.get(existing.CampaignId).add(existing.Label.toLowerCase());

            Integer sortOrder = existing.SortOrder == null ? 0 : existing.SortOrder;
            Integer maxSortOrder = maxSortOrderByCampaign.get(existing.CampaignId);
            if (maxSortOrder == null || sortOrder > maxSortOrder) {
                maxSortOrderByCampaign.put(existing.CampaignId, sortOrder);
            }
        }

        List<CampaignMemberStatus> statusesToInsert = new List<CampaignMemberStatus>();
        for (Id campaignId : campaignIds) {
            Set<String> existing = existingByCampaign.containsKey(campaignId) ? existingByCampaign.get(campaignId) : new Set<String>();
            Integer sortOrder = maxSortOrderByCampaign.containsKey(campaignId) ? maxSortOrderByCampaign.get(campaignId) : 0;
            for (String status : statusesByCampaign.get(campaignId)) {
                if (existing.contains(status.toLowerCase())) {
                    continue;
                }
                statusesToInsert.add(new CampaignMemberStatus(
                    CampaignId = campaignId,
                    Label = status,
                    HasResponded = !NOT_RESPONDED_STATUSES.contains(status),
                    SortOrder = ++sortOrder
                ));
            }
        }
        if (statusesToInsert.isEmpty()) {
            return;
        }

        // SortOrder must be unique per Campaign. The default statuses of a Campaign inserted in the same transaction
        // are not always returned by the query above, so rows that hit DUPLICATE_VALUE are retried once after the
        // highest SortOrder used. A label added by a parallel transaction fails again and is logged, which is fine.
        List<CampaignMemberStatus> retries = new List<CampaignMemberStatus>();
        List<Database.SaveResult> results = Database.insert(statusesToInsert, false, AccessLevel.SYSTEM_MODE);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess() && results[i].getErrors()[0].getStatusCode() == StatusCode.DUPLICATE_VALUE) {
                CampaignMemberStatus failed = statusesToInsert[i];
                retries.add(new CampaignMemberStatus(CampaignId = failed.CampaignId, Label = failed.Label, HasResponded = failed.HasResponded));
            }
        }
        if (retries.isEmpty()) {
            logFailures('CAMPAIGN MEMBER STATUS INSERT', results);
            return;
        }

        Map<Id, Integer> highestSortOrderByCampaign = new Map<Id, Integer>();
        for (CampaignMemberStatus status : statusesToInsert) {
            Integer highest = highestSortOrderByCampaign.get(status.CampaignId);
            if (highest == null || status.SortOrder > highest) {
                highestSortOrderByCampaign.put(status.CampaignId, status.SortOrder);
            }
        }
        for (CampaignMemberStatus retry : retries) {
            Integer sortOrder = highestSortOrderByCampaign.get(retry.CampaignId) + 1;
            retry.SortOrder = sortOrder;
            highestSortOrderByCampaign.put(retry.CampaignId, sortOrder);
        }
        logFailures('CAMPAIGN MEMBER STATUS INSERT', Database.insert(retries, false, AccessLevel.SYSTEM_MODE));
    }

    // Campaign_Member_Id__c is text, so ignore anything that is not a Campaign Member Id
    private static Id toCampaignMemberId(String value) {
        try {
            Id recordId = Id.valueOf(value);
            return recordId.getSObjectType() == CampaignMember.SObjectType ? recordId : null;
        } catch (StringException e) {
            return null;
        }
    }

    private static void logFailures(String context, List<Database.SaveResult> results) {
        for (Database.SaveResult result : results) {
            if (result.isSuccess()) {
                continue;
            }
            for (Database.Error error : result.getErrors()) {
                System.debug(LoggingLevel.ERROR, context + ' FAILED | ' + error.getStatusCode() + ': ' + error.getMessage());
            }
        }
    }
}
