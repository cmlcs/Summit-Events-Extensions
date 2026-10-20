/**
 * Flow action: copies a Registration's status to its linked Campaign Member (US-10).
 * Called by the Registration_Sync_Campaign_Member_Status flow. See CampaignMemberStatusSync.
 */
public without sharing class SyncCampaignMemberStatus {

    public class Request {
        @InvocableVariable(label='Registration Id' required=true)
        public Id registrationId;
    }

    @InvocableMethod(
        label='Sync Campaign Member Status'
        description='Sets the linked Campaign Member status to the Summit Events Registration status.'
        category='Summit Events'
    )
    public static void sync(List<Request> requests) {
        Set<Id> registrationIds = new Set<Id>();
        for (Request request : requests) {
            registrationIds.add(request.registrationId);
        }

        // Never block the Registration save; it may come from a guest user on the public site
        try {
            CampaignMemberStatusSync.syncFromRegistrations(registrationIds);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CAMPAIGN MEMBER STATUS SYNC FAILED | ' + e.getTypeName() + ': ' + e.getMessage());
        }
    }
}
