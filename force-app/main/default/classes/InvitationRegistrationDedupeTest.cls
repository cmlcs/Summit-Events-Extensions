@IsTest
private class InvitationRegistrationDedupeTest {
    private static final Integer BULK_SIZE = 600;

    @TestSetup
    static void setup() {
        summit__Summit_Events__c evt = new summit__Summit_Events__c(Name = 'Dedupe Test Gala');
        insert evt;
        insert new summit__Summit_Events_Instance__c(summit__Event__c = evt.Id, summit__Instance_Title__c = 'Dedupe Test Gala 2026');
        insert new List<Contact>{ new Contact(FirstName = 'Maria', LastName = 'Dedupetest'), new Contact(FirstName = 'Jan', LastName = 'Dedupetest') };
        insert new Lead(FirstName = 'Lea', LastName = 'Dedupetest', Company = 'Dedupe Test Company');
    }

    private static summit__Summit_Events_Instance__c getInstance() {
        return [SELECT Id, summit__Event__c FROM summit__Summit_Events_Instance__c WHERE summit__Instance_Title__c = 'Dedupe Test Gala 2026' LIMIT 1];
    }

    private static Contact getContact(String firstName) {
        return [SELECT Id FROM Contact WHERE FirstName = :firstName AND LastName = 'Dedupetest' LIMIT 1];
    }

    private static Lead getLead() {
        return [SELECT Id FROM Lead WHERE LastName = 'Dedupetest' LIMIT 1];
    }

    // The service never queries Campaign Members, so generated Ids are enough to key requests and results
    private static Id campaignMemberId(Integer n) {
        return Id.valueOf(CampaignMember.SObjectType.getDescribe().getKeyPrefix() + String.valueOf(n).leftPad(12, '0'));
    }

    private static InvitationRegistrationDedupe.Request request(Id instanceId, Id contactId, Id leadId, Integer cmNumber) {
        return new InvitationRegistrationDedupe.Request(instanceId, contactId, leadId, cmNumber == null ? null : campaignMemberId(cmNumber));
    }

    private static summit__Summit_Events_Registration__c newRegistration(summit__Summit_Events_Instance__c instance, Id contactId, Id leadId) {
        return new summit__Summit_Events_Registration__c(
            summit__Event_Instance__c = instance.Id,
            summit__Event__c = instance.summit__Event__c,
            summit__Contact__c = contactId,
            summit__Lead__c = leadId
        );
    }

    // Assert messages must not be null
    private static String messageOf(String message) {
        return message == null ? '' : message;
    }

    private static Integer countRegistrations(Id instanceId) {
        return [SELECT COUNT() FROM summit__Summit_Events_Registration__c WHERE summit__Event_Instance__c = :instanceId];
    }

    @IsTest
    static void buildKeyPrefersContactAndRequiresPerson() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id contactId = getContact('Maria').Id;
        Id leadId = getLead().Id;

        Assert.areEqual(instance.Id + ':' + contactId, InvitationRegistrationDedupe.buildKey(instance.Id, contactId, leadId), 'Contact wins over Lead');
        Assert.areEqual(instance.Id + ':' + leadId, InvitationRegistrationDedupe.buildKey(instance.Id, null, leadId), 'Lead used without Contact');
        Assert.isNull(InvitationRegistrationDedupe.buildKey(instance.Id, null, null), 'No person, no key');
        Assert.isNull(InvitationRegistrationDedupe.buildKey(null, contactId, null), 'No instance, no key');
        Assert.areEqual(37, InvitationRegistrationDedupe.buildKey(instance.Id, contactId, null).length(), 'Key uses 18-character Ids');
    }

    @IsTest
    static void noExistingRegistrationNeedsNewOne() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Test.startTest();
        Map<Id, InvitationRegistrationDedupe.Result> results = InvitationRegistrationDedupe.resolve(
            new List<InvitationRegistrationDedupe.Request>{ request(instance.Id, getContact('Maria').Id, null, 1) }
        );
        Test.stopTest();
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.NEW_REGISTRATION_NEEDED, results.get(campaignMemberId(1)).outcome);
        Assert.isNull(results.get(campaignMemberId(1)).registration);
    }

    @IsTest
    static void reprocessingSamePersonDoesNotCreateSecondRegistration() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id contactId = getContact('Maria').Id;

        Test.startTest();
        InvitationRegistrationDedupe.Result first = InvitationRegistrationDedupe.insertRegistrations(
                new Map<Id, summit__Summit_Events_Registration__c>{ campaignMemberId(1) => newRegistration(instance, contactId, null) }
            )
            .get(campaignMemberId(1));
        // Removing and re-adding Maria gives a new Campaign Member Id but resolves to the same Registration
        InvitationRegistrationDedupe.Result second = InvitationRegistrationDedupe.resolve(
                new List<InvitationRegistrationDedupe.Request>{ request(instance.Id, contactId, null, 2) }
            )
            .get(campaignMemberId(2));
        // A caller that skips resolve still cannot insert a duplicate
        InvitationRegistrationDedupe.Result third = InvitationRegistrationDedupe.insertRegistrations(
                new Map<Id, summit__Summit_Events_Registration__c>{ campaignMemberId(3) => newRegistration(instance, contactId, null) }
            )
            .get(campaignMemberId(3));
        Test.stopTest();

        Assert.areEqual(InvitationRegistrationDedupe.Outcome.CREATED, first.outcome, messageOf(first.message));
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, second.outcome);
        Assert.areEqual(first.registration.Id, second.registration.Id);
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, third.outcome, messageOf(third.message));
        Assert.areEqual(first.registration.Id, third.registration.Id);
        Assert.areEqual(campaignMemberId(3), third.request.campaignMemberId, 'Result carries the Campaign Member it was created for');
        Assert.areEqual(1, countRegistrations(instance.Id));
    }

    @IsTest
    static void existingPublicRegistrationIsAdoptedAndPreserved() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id contactId = getContact('Maria').Id;
        summit__Summit_Events_Registration__c publicReg = newRegistration(instance, contactId, null);
        publicReg.summit__Status__c = 'Registered';
        publicReg.summit__Add_Info_Answer_1__c = 'Vegetarian';
        insert publicReg;

        Test.startTest();
        InvitationRegistrationDedupe.Result result = InvitationRegistrationDedupe.resolve(
                new List<InvitationRegistrationDedupe.Request>{ request(instance.Id, contactId, null, 1) }
            )
            .get(campaignMemberId(1));
        Test.stopTest();

        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, result.outcome);
        summit__Summit_Events_Registration__c reloaded = [
            SELECT summit__Status__c, summit__Add_Info_Answer_1__c, Invitation_Key__c
            FROM summit__Summit_Events_Registration__c
            WHERE Id = :publicReg.Id
            WITH SYSTEM_MODE
        ];
        Assert.areEqual('Registered', reloaded.summit__Status__c, 'Status is not overwritten');
        Assert.areEqual('Vegetarian', reloaded.summit__Add_Info_Answer_1__c, 'Answers are not overwritten');
        Assert.areEqual(result.invitationKey, reloaded.Invitation_Key__c, 'Adopted Registration gets the key');
        Assert.areEqual(1, countRegistrations(instance.Id));
    }

    @IsTest
    static void activeRegistrationPreferredOverCancelled() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id contactId = getContact('Maria').Id;
        summit__Summit_Events_Registration__c cancelled = newRegistration(instance, contactId, null);
        cancelled.summit__Status__c = 'Cancelled';
        summit__Summit_Events_Registration__c active = newRegistration(instance, contactId, null);
        active.summit__Status__c = 'Registered';
        insert new List<summit__Summit_Events_Registration__c>{ cancelled, active };

        List<InvitationRegistrationDedupe.Result> results = InvitationRegistrationDedupe.findExisting(
            new List<InvitationRegistrationDedupe.Request>{ request(instance.Id, contactId, null, null) }
        );
        Assert.areEqual(active.Id, results[0].registration.Id);
    }

    @IsTest
    static void blankPersonIsNeverMatched() {
        summit__Summit_Events_Instance__c instance = getInstance();
        // A Registration without Contact or Lead (e.g. unmatched public registration)
        insert newRegistration(instance, null, null);

        Map<Id, InvitationRegistrationDedupe.Result> results = InvitationRegistrationDedupe.resolve(
            new List<InvitationRegistrationDedupe.Request>{ request(instance.Id, null, null, 1), request(instance.Id, getContact('Jan').Id, null, 2) }
        );
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.SKIPPED_NO_PERSON, results.get(campaignMemberId(1)).outcome);
        Assert.areEqual(
            InvitationRegistrationDedupe.Outcome.NEW_REGISTRATION_NEEDED,
            results.get(campaignMemberId(2)).outcome,
            'Blank-person Registration must not match a Contact'
        );

        // Several Registrations without a person can coexist: blank keys do not collide
        Map<Id, InvitationRegistrationDedupe.Result> inserted = InvitationRegistrationDedupe.insertRegistrations(
            new Map<Id, summit__Summit_Events_Registration__c>{
                campaignMemberId(3) => newRegistration(instance, null, null),
                campaignMemberId(4) => newRegistration(instance, null, null)
            }
        );
        for (InvitationRegistrationDedupe.Result res : inserted.values()) {
            Assert.areEqual(InvitationRegistrationDedupe.Outcome.CREATED, res.outcome, messageOf(res.message));
        }
    }

    @IsTest
    static void leadInviteeIsMatchedByLead() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id leadId = getLead().Id;
        InvitationRegistrationDedupe.insertRegistrations(new Map<Id, summit__Summit_Events_Registration__c>{ campaignMemberId(1) => newRegistration(instance, null, leadId) });

        Map<Id, InvitationRegistrationDedupe.Result> results = InvitationRegistrationDedupe.resolve(
            new List<InvitationRegistrationDedupe.Request>{ request(instance.Id, null, leadId, 2) }
        );
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, results.get(campaignMemberId(2)).outcome);
    }

    @IsTest
    static void samePersonTwiceInOneCallIsFlagged() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id contactId = getContact('Maria').Id;

        // Same person through two Campaign Members, e.g. two Campaigns linked to the same Event Instance
        Map<Id, InvitationRegistrationDedupe.Result> found = InvitationRegistrationDedupe.resolve(
            new List<InvitationRegistrationDedupe.Request>{ request(instance.Id, contactId, null, 1), request(instance.Id, contactId, null, 2) }
        );
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.NEW_REGISTRATION_NEEDED, found.get(campaignMemberId(1)).outcome);
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.DUPLICATE_IN_REQUEST, found.get(campaignMemberId(2)).outcome);

        // Same person twice in one insert: the unique key lets only one through
        Map<Id, InvitationRegistrationDedupe.Result> inserted = InvitationRegistrationDedupe.insertRegistrations(
            new Map<Id, summit__Summit_Events_Registration__c>{
                campaignMemberId(1) => newRegistration(instance, contactId, null),
                campaignMemberId(2) => newRegistration(instance, contactId, null)
            }
        );
        Assert.areEqual(1, countRegistrations(instance.Id));
        Set<InvitationRegistrationDedupe.Outcome> outcomes = new Set<InvitationRegistrationDedupe.Outcome>();
        for (InvitationRegistrationDedupe.Result res : inserted.values()) {
            outcomes.add(res.outcome);
        }
        Assert.areEqual(
            new Set<InvitationRegistrationDedupe.Outcome>{ InvitationRegistrationDedupe.Outcome.CREATED, InvitationRegistrationDedupe.Outcome.EXISTING_FOUND },
            outcomes
        );
    }

    // Event Manager with the Summit Events Admin permission set but without Summit_Events_Invitation_Admin
    // (no access to Invitation_Key__c). Note: SEA's registration trigger throws a NullPointerException for
    // users without read access to Summit_Events__c, so a user without any SEA permission cannot be used here.
    @IsTest
    static void worksForUserWithoutInvitationFieldAccess() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id contactId = getContact('Maria').Id;
        insert newRegistration(instance, contactId, null);
        User eventManager = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
            LastName = 'Dedupetest',
            Alias = 'ddtest',
            Email = 'dedupetest@example.invalid',
            Username = 'dedupetest' + System.currentTimeMillis() + '@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Amsterdam'
        );
        // Setup objects in their own context to avoid mixed DML with the Registration insert above
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert eventManager;
            insert new PermissionSetAssignment(
                AssigneeId = eventManager.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'Summit_Events_Admin' LIMIT 1].Id
            );
        }

        InvitationRegistrationDedupe.Result result;
        System.runAs(eventManager) {
            result = InvitationRegistrationDedupe.resolve(new List<InvitationRegistrationDedupe.Request>{ request(instance.Id, contactId, null, 1) })
                .get(campaignMemberId(1));
        }
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, result.outcome, messageOf(result.message));
        Assert.areEqual(1, countRegistrations(instance.Id));
    }

    @IsTest
    static void missingEventInstanceThrows() {
        try {
            InvitationRegistrationDedupe.resolve(new List<InvitationRegistrationDedupe.Request>{ request(null, null, null, 1) });
            Assert.fail('Expected InvitationProcessingException');
        } catch (InvitationProcessingException e) {
            Assert.isTrue(e.getMessage().contains('Event Instance'));
        }
    }

    @IsTest
    static void missingOrRepeatedCampaignMemberIdThrows() {
        Id instanceId = getInstance().Id;
        Id contactId = getContact('Maria').Id;
        List<List<InvitationRegistrationDedupe.Request>> invalidInputs = new List<List<InvitationRegistrationDedupe.Request>>{
            new List<InvitationRegistrationDedupe.Request>{ request(instanceId, contactId, null, null) },
            new List<InvitationRegistrationDedupe.Request>{ request(instanceId, contactId, null, 1), request(instanceId, getContact('Jan').Id, null, 1) }
        };
        for (List<InvitationRegistrationDedupe.Request> requests : invalidInputs) {
            try {
                InvitationRegistrationDedupe.resolve(requests);
                Assert.fail('Expected InvitationProcessingException');
            } catch (InvitationProcessingException e) {
                Assert.isTrue(e.getMessage().contains('Campaign Member Id'));
            }
        }
    }

    @IsTest
    static void bulkSixHundredInviteesProcessedTwice() {
        summit__Summit_Events_Instance__c instance = getInstance();
        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            contacts.add(new Contact(FirstName = 'Bulk' + i, LastName = 'Dedupetest'));
        }
        insert contacts;

        List<InvitationRegistrationDedupe.Request> requests = new List<InvitationRegistrationDedupe.Request>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            requests.add(request(instance.Id, contacts[i].Id, null, i));
        }

        Test.startTest();
        Map<Id, summit__Summit_Events_Registration__c> toCreate = new Map<Id, summit__Summit_Events_Registration__c>();
        for (InvitationRegistrationDedupe.Result res : InvitationRegistrationDedupe.resolve(requests).values()) {
            Assert.areEqual(InvitationRegistrationDedupe.Outcome.NEW_REGISTRATION_NEEDED, res.outcome);
            toCreate.put(res.request.campaignMemberId, newRegistration(instance, res.request.contactId, null));
        }
        Map<Id, InvitationRegistrationDedupe.Result> created = InvitationRegistrationDedupe.insertRegistrations(toCreate);
        Assert.areEqual(BULK_SIZE, created.size());
        for (InvitationRegistrationDedupe.Result res : created.values()) {
            Assert.areEqual(InvitationRegistrationDedupe.Outcome.CREATED, res.outcome, messageOf(res.message));
        }
        // Reprocess the whole Campaign
        for (InvitationRegistrationDedupe.Result res : InvitationRegistrationDedupe.resolve(requests).values()) {
            Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, res.outcome);
        }
        Test.stopTest();

        Assert.areEqual(BULK_SIZE, countRegistrations(instance.Id));
    }
}
