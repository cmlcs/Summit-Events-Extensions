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
        List<InvitationRegistrationDedupe.Result> results = InvitationRegistrationDedupe.resolve(
            new List<InvitationRegistrationDedupe.Request>{ new InvitationRegistrationDedupe.Request(instance.Id, getContact('Maria').Id, null, null) }
        );
        Test.stopTest();
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.NEW_REGISTRATION_NEEDED, results[0].outcome);
        Assert.isNull(results[0].registration);
    }

    @IsTest
    static void reprocessingSamePersonDoesNotCreateSecondRegistration() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id contactId = getContact('Maria').Id;

        Test.startTest();
        List<InvitationRegistrationDedupe.Result> first = InvitationRegistrationDedupe.insertRegistrations(
            new List<summit__Summit_Events_Registration__c>{ newRegistration(instance, contactId, null) }
        );
        // Re-adding Maria later (e.g. new Campaign Member Id) resolves to the same Registration
        List<InvitationRegistrationDedupe.Result> second = InvitationRegistrationDedupe.resolve(
            new List<InvitationRegistrationDedupe.Request>{ new InvitationRegistrationDedupe.Request(instance.Id, contactId, null, null) }
        );
        // A caller that skips resolve still cannot insert a duplicate
        List<InvitationRegistrationDedupe.Result> third = InvitationRegistrationDedupe.insertRegistrations(
            new List<summit__Summit_Events_Registration__c>{ newRegistration(instance, contactId, null) }
        );
        Test.stopTest();

        Assert.areEqual(InvitationRegistrationDedupe.Outcome.CREATED, first[0].outcome);
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, second[0].outcome);
        Assert.areEqual(first[0].registration.Id, second[0].registration.Id);
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, third[0].outcome, messageOf(third[0].message));
        Assert.areEqual(first[0].registration.Id, third[0].registration.Id);
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
        List<InvitationRegistrationDedupe.Result> results = InvitationRegistrationDedupe.resolve(
            new List<InvitationRegistrationDedupe.Request>{ new InvitationRegistrationDedupe.Request(instance.Id, contactId, null, null) }
        );
        Test.stopTest();

        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, results[0].outcome);
        summit__Summit_Events_Registration__c reloaded = [
            SELECT summit__Status__c, summit__Add_Info_Answer_1__c, Invitation_Key__c
            FROM summit__Summit_Events_Registration__c
            WHERE Id = :publicReg.Id
            WITH SYSTEM_MODE
        ];
        Assert.areEqual('Registered', reloaded.summit__Status__c, 'Status is not overwritten');
        Assert.areEqual('Vegetarian', reloaded.summit__Add_Info_Answer_1__c, 'Answers are not overwritten');
        Assert.areEqual(results[0].invitationKey, reloaded.Invitation_Key__c, 'Adopted Registration gets the key');
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
            new List<InvitationRegistrationDedupe.Request>{ new InvitationRegistrationDedupe.Request(instance.Id, contactId, null, null) }
        );
        Assert.areEqual(active.Id, results[0].registration.Id);
    }

    @IsTest
    static void blankPersonIsNeverMatched() {
        summit__Summit_Events_Instance__c instance = getInstance();
        // A Registration without Contact or Lead (e.g. unmatched public registration)
        insert newRegistration(instance, null, null);

        List<InvitationRegistrationDedupe.Result> results = InvitationRegistrationDedupe.findExisting(
            new List<InvitationRegistrationDedupe.Request>{
                new InvitationRegistrationDedupe.Request(instance.Id, null, null, null),
                new InvitationRegistrationDedupe.Request(instance.Id, getContact('Jan').Id, null, null)
            }
        );
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.SKIPPED_NO_PERSON, results[0].outcome);
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.NEW_REGISTRATION_NEEDED, results[1].outcome, 'Blank-person Registration must not match a Contact');

        // Several Registrations without a person can coexist: blank keys do not collide
        List<InvitationRegistrationDedupe.Result> inserted = InvitationRegistrationDedupe.insertRegistrations(
            new List<summit__Summit_Events_Registration__c>{ newRegistration(instance, null, null), newRegistration(instance, null, null) }
        );
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.CREATED, inserted[0].outcome, messageOf(inserted[0].message));
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.CREATED, inserted[1].outcome, messageOf(inserted[1].message));
    }

    @IsTest
    static void leadInviteeIsMatchedByLead() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id leadId = getLead().Id;
        InvitationRegistrationDedupe.insertRegistrations(new List<summit__Summit_Events_Registration__c>{ newRegistration(instance, null, leadId) });

        List<InvitationRegistrationDedupe.Result> results = InvitationRegistrationDedupe.findExisting(
            new List<InvitationRegistrationDedupe.Request>{ new InvitationRegistrationDedupe.Request(instance.Id, null, leadId, null) }
        );
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, results[0].outcome);
    }

    @IsTest
    static void samePersonTwiceInOneCallIsFlagged() {
        summit__Summit_Events_Instance__c instance = getInstance();
        Id contactId = getContact('Maria').Id;

        List<InvitationRegistrationDedupe.Result> found = InvitationRegistrationDedupe.findExisting(
            new List<InvitationRegistrationDedupe.Request>{
                new InvitationRegistrationDedupe.Request(instance.Id, contactId, null, null),
                new InvitationRegistrationDedupe.Request(instance.Id, contactId, null, null)
            }
        );
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.NEW_REGISTRATION_NEEDED, found[0].outcome);
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.DUPLICATE_IN_REQUEST, found[1].outcome);

        // Same person twice in one insert: the unique key lets only one through
        List<InvitationRegistrationDedupe.Result> inserted = InvitationRegistrationDedupe.insertRegistrations(
            new List<summit__Summit_Events_Registration__c>{ newRegistration(instance, contactId, null), newRegistration(instance, contactId, null) }
        );
        Assert.areEqual(1, countRegistrations(instance.Id));
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.CREATED, inserted[0].outcome, messageOf(inserted[0].message));
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, inserted[1].outcome, messageOf(inserted[1].message));
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

        List<InvitationRegistrationDedupe.Result> results;
        System.runAs(eventManager) {
            results = InvitationRegistrationDedupe.resolve(
                new List<InvitationRegistrationDedupe.Request>{ new InvitationRegistrationDedupe.Request(instance.Id, contactId, null, null) }
            );
        }
        Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, results[0].outcome, messageOf(results[0].message));
        Assert.areEqual(1, countRegistrations(instance.Id));
    }

    @IsTest
    static void missingEventInstanceThrows() {
        try {
            InvitationRegistrationDedupe.findExisting(new List<InvitationRegistrationDedupe.Request>{ new InvitationRegistrationDedupe.Request(null, null, null, null) });
            Assert.fail('Expected InvitationProcessingException');
        } catch (InvitationProcessingException e) {
            Assert.isTrue(e.getMessage().contains('Event Instance'));
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
        for (Contact c : contacts) {
            requests.add(new InvitationRegistrationDedupe.Request(instance.Id, c.Id, null, null));
        }

        Test.startTest();
        List<summit__Summit_Events_Registration__c> toCreate = new List<summit__Summit_Events_Registration__c>();
        for (InvitationRegistrationDedupe.Result res : InvitationRegistrationDedupe.resolve(requests)) {
            Assert.areEqual(InvitationRegistrationDedupe.Outcome.NEW_REGISTRATION_NEEDED, res.outcome);
            toCreate.add(newRegistration(instance, res.request.contactId, null));
        }
        for (InvitationRegistrationDedupe.Result res : InvitationRegistrationDedupe.insertRegistrations(toCreate)) {
            Assert.areEqual(InvitationRegistrationDedupe.Outcome.CREATED, res.outcome, messageOf(res.message));
        }
        // Reprocess the whole Campaign
        for (InvitationRegistrationDedupe.Result res : InvitationRegistrationDedupe.resolve(requests)) {
            Assert.areEqual(InvitationRegistrationDedupe.Outcome.EXISTING_FOUND, res.outcome);
        }
        Test.stopTest();

        Assert.areEqual(BULK_SIZE, countRegistrations(instance.Id));
    }
}
