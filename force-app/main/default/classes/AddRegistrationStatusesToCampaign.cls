/**
 * Flow action: adds the Summit Events Registration statuses to Campaigns linked to an Event Instance (US-10).
 * Called by the Campaign_Add_Registration_Statuses flow. See CampaignMemberStatusSync.
 */
public without sharing class AddRegistrationStatusesToCampaign {

    public class Request {
        @InvocableVariable(label='Campaign Id' required=true)
        public Id campaignId;
    }

    @InvocableMethod(
        label='Add Registration Statuses to Campaign'
        description='Adds each active Summit Events Registration status as a Campaign Member Status to Campaigns linked to an Event Instance.'
        category='Summit Events'
    )
    public static void addStatuses(List<Request> requests) {
        Set<Id> campaignIds = new Set<Id>();
        for (Request request : requests) {
            campaignIds.add(request.campaignId);
        }

        // Never block the Campaign save
        try {
            CampaignMemberStatusSync.addRegistrationStatuses(campaignIds);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ADD REGISTRATION STATUSES FAILED | ' + e.getTypeName() + ': ' + e.getMessage());
        }
    }
}
