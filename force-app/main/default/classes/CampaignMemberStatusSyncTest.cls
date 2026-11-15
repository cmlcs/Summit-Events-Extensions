/**
 * US-10 tests. They run through DML, so both flows (Campaign_Add_Registration_Statuses and
 * Registration_Sync_Campaign_Member_Status) must be active in the target org.
 *
 * Campaign Members use Registration statuses other than Invited, so the CampaignMember trigger does not enqueue
 * SummitInvitationQueueable.
 */
@IsTest
private class CampaignMemberStatusSyncTest {

    private static Id createEventInstance() {
        summit__Summit_Events__c event = new summit__Summit_Events__c(Name = 'Test Gala');
        insert as system event;
        summit__Summit_Events_Instance__c instance = new summit__Summit_Events_Instance__c(summit__Event__c = event.Id);
        insert as system instance;
        return instance.Id;
    }

    private static Campaign createCampaign(Id instanceId) {
        // System mode: at API 68.0 test DML checks the running user's access, and the test runner may not be a Marketing User
        Campaign campaign = new Campaign(Name = 'Test Gala Invitations', IsActive = true, Summit_Events_Instance__c = instanceId);
        insert as system campaign;
        return campaign;
    }

    private static List<Contact> createContacts(Integer count) {
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            contacts.add(new Contact(LastName = 'Invitee ' + i));
        }
        insert as system contacts;
        return contacts;
    }

    private static List<CampaignMember> createMembers(Campaign campaign, List<Contact> contacts, String status) {
        List<CampaignMember> members = new List<CampaignMember>();
        for (Contact contact : contacts) {
            members.add(new CampaignMember(CampaignId = campaign.Id, ContactId = contact.Id, Status = status));
        }
        insert as system members;
        return members;
    }

    private static List<summit__Summit_Events_Registration__c> createRegistrations(Id instanceId, List<CampaignMember> members, String status) {
        List<summit__Summit_Events_Registration__c> registrations = new List<summit__Summit_Events_Registration__c>();
        for (CampaignMember member : members) {
            registrations.add(new summit__Summit_Events_Registration__c(
                summit__Event_Instance__c = instanceId,
                summit__Contact__c = member.ContactId,
                summit__Status__c = status,
                Campaign_Member_Id__c = member.Id
            ));
        }
        insert as system registrations;
        return registrations;
    }

    private static Map<String, CampaignMemberStatus> statusesByLabel(Id campaignId) {
        Map<String, CampaignMemberStatus> result = new Map<String, CampaignMemberStatus>();
        for (CampaignMemberStatus status : [
            SELECT Label, HasResponded, IsDefault, SortOrder
            FROM CampaignMemberStatus
            WHERE CampaignId = :campaignId
            WITH SYSTEM_MODE
        ]) {
            result.put(status.Label, status);
        }
        return result;
    }

    private static String memberStatus(Id memberId) {
        return [SELECT Status FROM CampaignMember WHERE Id = :memberId WITH SYSTEM_MODE].Status;
    }

    private static void updateStatus(List<summit__Summit_Events_Registration__c> registrations, String status) {
        List<summit__Summit_Events_Registration__c> updates = new List<summit__Summit_Events_Registration__c>();
        for (summit__Summit_Events_Registration__c registration : registrations) {
            updates.add(new summit__Summit_Events_Registration__c(Id = registration.Id, summit__Status__c = status));
        }
        update as system updates;
    }

    @IsTest
    static void linkedCampaignGetsEveryRegistrationStatus() {
        Test.startTest();
        Campaign campaign = createCampaign(createEventInstance());
        Test.stopTest();

        Map<String, CampaignMemberStatus> statuses = statusesByLabel(campaign.Id);
        List<String> registrationStatuses = CampaignMemberStatusSync.registrationStatuses();
        Assert.isFalse(registrationStatuses.isEmpty(), 'summit__Status__c must have active values');
        for (String status : registrationStatuses) {
            Assert.isTrue(statuses.containsKey(status), 'Missing Campaign Member Status ' + status);
            Assert.areEqual(!CampaignMemberStatusSync.NOT_RESPONDED_STATUSES.contains(status), statuses.get(status).HasResponded, 'HasResponded for ' + status);
        }
        Assert.areEqual(statuses.size(), new Set<Integer>(sortOrders(statuses.values())).size(), 'Sort orders must be unique');
    }

    @IsTest
    static void defaultStatusIsUnchanged() {
        Campaign unlinked = createCampaign(null);
        String defaultBefore = defaultLabel(unlinked.Id);

        Test.startTest();
        update as system new Campaign(Id = unlinked.Id, Summit_Events_Instance__c = createEventInstance());
        Test.stopTest();

        Assert.areEqual(defaultBefore, defaultLabel(unlinked.Id), 'The default status must stay the same');
    }

    @IsTest
    static void campaignWithoutInstanceIsUntouched() {
        Test.startTest();
        Campaign campaign = createCampaign(null);
        Test.stopTest();

        Map<String, CampaignMemberStatus> statuses = statusesByLabel(campaign.Id);
        for (String status : CampaignMemberStatusSync.registrationStatuses()) {
            Assert.isFalse(statuses.containsKey(status), 'Unlinked Campaign must not get status ' + status);
        }
    }

    @IsTest
    static void linkingAnExistingCampaignAddsStatuses() {
        Campaign campaign = createCampaign(null);

        Test.startTest();
        update as system new Campaign(Id = campaign.Id, Summit_Events_Instance__c = createEventInstance());
        Test.stopTest();

        Assert.isTrue(statusesByLabel(campaign.Id).keySet().containsAll(CampaignMemberStatusSync.registrationStatuses()), 'All Registration statuses expected');
    }

    @IsTest
    static void addingStatusesTwiceIsIdempotent() {
        Campaign campaign = createCampaign(createEventInstance());
        Integer countBefore = statusesByLabel(campaign.Id).size();

        Test.startTest();
        CampaignMemberStatusSync.addRegistrationStatuses(new Set<Id>{ campaign.Id });
        AddRegistrationStatusesToCampaign.Request request = new AddRegistrationStatusesToCampaign.Request();
        request.campaignId = campaign.Id;
        AddRegistrationStatusesToCampaign.addStatuses(new List<AddRegistrationStatusesToCampaign.Request>{ request });
        Test.stopTest();

        Assert.areEqual(countBefore, statusesByLabel(campaign.Id).size(), 'No duplicate statuses');
    }

    @IsTest
    static void registrationStatusIsCopiedToMember() {
        Id instanceId = createEventInstance();
        Campaign campaign = createCampaign(instanceId);
        List<CampaignMember> members = createMembers(campaign, createContacts(1), 'Registered');

        Test.startTest();
        List<summit__Summit_Events_Registration__c> registrations = createRegistrations(instanceId, members, 'Confirmed');
        Assert.areEqual('Confirmed', memberStatus(members[0].Id), 'Insert syncs the status');

        updateStatus(registrations, 'Declined');
        Test.stopTest();

        Assert.areEqual('Declined', memberStatus(members[0].Id), 'Update syncs the status');
    }

    @IsTest
    static void linkingAMemberLaterSyncsItsStatus() {
        Id instanceId = createEventInstance();
        Campaign campaign = createCampaign(instanceId);
        List<CampaignMember> members = createMembers(campaign, createContacts(1), 'Registered');
        summit__Summit_Events_Registration__c registration = new summit__Summit_Events_Registration__c(
            summit__Event_Instance__c = instanceId,
            summit__Contact__c = members[0].ContactId,
            summit__Status__c = 'Attended'
        );
        insert as system registration;
        Assert.areEqual('Registered', memberStatus(members[0].Id), 'Not linked yet');

        Test.startTest();
        update as system new summit__Summit_Events_Registration__c(Id = registration.Id, Campaign_Member_Id__c = members[0].Id);
        Test.stopTest();

        Assert.areEqual('Attended', memberStatus(members[0].Id), 'Linking syncs the status');
    }

    @IsTest
    static void missingStatusIsAddedBeforeSync() {
        Id instanceId = createEventInstance();
        Campaign campaign = createCampaign(instanceId);
        List<CampaignMember> members = createMembers(campaign, createContacts(1), 'Registered');
        List<summit__Summit_Events_Registration__c> registrations = createRegistrations(instanceId, members, 'Registered');
        // Stands in for a picklist value added after the Campaign was linked
        delete as system [SELECT Id FROM CampaignMemberStatus WHERE CampaignId = :campaign.Id AND Label = 'Attended' WITH SYSTEM_MODE];

        Test.startTest();
        updateStatus(registrations, 'Attended');
        Test.stopTest();

        Assert.isTrue(statusesByLabel(campaign.Id).containsKey('Attended'), 'Status re-added');
        Assert.areEqual('Attended', memberStatus(members[0].Id));
    }

    @IsTest
    static void invalidOrDeletedMemberIdsAreIgnored() {
        Id instanceId = createEventInstance();
        Campaign campaign = createCampaign(instanceId);
        List<Contact> contacts = createContacts(3);
        List<CampaignMember> members = createMembers(campaign, contacts, 'Registered');
        delete as system members[1];

        List<summit__Summit_Events_Registration__c> registrations = new List<summit__Summit_Events_Registration__c>{
            new summit__Summit_Events_Registration__c(summit__Event_Instance__c = instanceId, summit__Contact__c = contacts[0].Id, summit__Status__c = 'Registered', Campaign_Member_Id__c = 'not-an-id'),
            new summit__Summit_Events_Registration__c(summit__Event_Instance__c = instanceId, summit__Contact__c = contacts[1].Id, summit__Status__c = 'Registered', Campaign_Member_Id__c = members[1].Id),
            new summit__Summit_Events_Registration__c(summit__Event_Instance__c = instanceId, summit__Contact__c = contacts[2].Id, summit__Status__c = 'Registered', Campaign_Member_Id__c = contacts[2].Id)
        };

        Test.startTest();
        insert as system registrations;
        updateStatus(registrations, 'Cancelled');
        Test.stopTest();

        Assert.areEqual('Registered', memberStatus(members[0].Id), 'Unlinked member is unchanged');
        Assert.areEqual('Registered', memberStatus(members[2].Id), 'Unlinked member is unchanged');
    }

    @IsTest
    static void syncActionIgnoresRegistrationsWithoutMember() {
        Id instanceId = createEventInstance();
        summit__Summit_Events_Registration__c registration = new summit__Summit_Events_Registration__c(summit__Event_Instance__c = instanceId, summit__Status__c = 'Registered');
        insert as system registration;

        SyncCampaignMemberStatus.Request request = new SyncCampaignMemberStatus.Request();
        request.registrationId = registration.Id;

        Test.startTest();
        SyncCampaignMemberStatus.sync(new List<SyncCampaignMemberStatus.Request>{ request });
        CampaignMemberStatusSync.syncFromRegistrations(new Set<Id>{ null });
        CampaignMemberStatusSync.addRegistrationStatuses(new Set<Id>{ null });
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM CampaignMember WITH SYSTEM_MODE], 'Nothing to sync');
    }

    @IsTest
    static void sixHundredMembersAreSynced() {
        Id instanceId = createEventInstance();
        Campaign campaign = createCampaign(instanceId);
        List<CampaignMember> members = createMembers(campaign, createContacts(600), 'Registered');
        List<summit__Summit_Events_Registration__c> registrations = createRegistrations(instanceId, members, 'Registered');

        Test.startTest();
        updateStatus(registrations, 'Attended');
        Test.stopTest();

        Assert.areEqual(600, [SELECT COUNT() FROM CampaignMember WHERE CampaignId = :campaign.Id AND Status = 'Attended' WITH SYSTEM_MODE], 'All 600 members synced');
    }

    private static List<Integer> sortOrders(List<CampaignMemberStatus> statuses) {
        List<Integer> result = new List<Integer>();
        for (CampaignMemberStatus status : statuses) {
            result.add(status.SortOrder);
        }
        return result;
    }

    private static String defaultLabel(Id campaignId) {
        for (CampaignMemberStatus status : statusesByLabel(campaignId).values()) {
            if (status.IsDefault) {
                return status.Label;
            }
        }
        return null;
    }
}
