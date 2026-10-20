/**
 * Tests for US-08 (decline an invitation): InvitationDeclineController and InvitationLink.
 *
 * Requires the 'Invited' and 'Declined' values on summit__Summit_Events_Registration__c.summit__Status__c in the
 * target org; the package does not ship them.
 */
@IsTest
private class InvitationDeclineControllerTest {
    private static final Integer BULK_SIZE = 600;

    @TestSetup
    static void setup() {
        summit__Summit_Events_Settings__c settings = summit__Summit_Events_Settings__c.getOrgDefaults();
        settings.summit__Cookie_Encryption_Key__c = EncodingUtil.base64Encode(Crypto.generateAesKey(256)).substring(0, 32);
        upsert settings;

        summit__Summit_Events__c evt = new summit__Summit_Events__c(Name = 'Decline Test Gala', summit__Event_Name__c = 'Decline Test Gala');
        insert evt;
        insert new summit__Summit_Events_Instance__c(summit__Event__c = evt.Id, summit__Instance_Title__c = 'Decline Test Gala 2026');
    }

    private static summit__Summit_Events_Registration__c createRegistration(String status) {
        summit__Summit_Events_Instance__c instance = [
            SELECT Id, summit__Event__c
            FROM summit__Summit_Events_Instance__c
            WHERE summit__Instance_Title__c = 'Decline Test Gala 2026'
            LIMIT 1
        ];
        summit__Summit_Events_Registration__c registration = new summit__Summit_Events_Registration__c(
            summit__Event_Instance__c = instance.Id,
            summit__Event__c = instance.summit__Event__c,
            summit__Registrant_First_Name__c = 'Thomas',
            summit__Registrant_Last_Name__c = 'Ambassador',
            summit__Registrant_Email__c = 'thomas@example.invalid',
            summit__Status__c = status
        );
        insert registration;
        InvitationLink.setEncryptedFields(registration);
        update registration;
        return registration;
    }

    // The decline link concatenates both encrypted fields; the platform URL-decodes the parameter once
    private static String getLinkParameter(summit__Summit_Events_Registration__c registration) {
        String encrypted = registration.summit__Encrypted_Registration_Id_1__c;
        if (String.isNotBlank(registration.summit__Encrypted_Registration_Id_2__c)) {
            encrypted += registration.summit__Encrypted_Registration_Id_2__c;
        }
        return EncodingUtil.urlDecode(encrypted, 'UTF-8');
    }

    private static InvitationDeclineController openDeclinePage(String eventInfo) {
        Test.setCurrentPage(Page.InvitationDecline);
        if (eventInfo != null) {
            ApexPages.currentPage().getParameters().put('eventInfo', eventInfo);
        }
        return new InvitationDeclineController();
    }

    private static String getStatus(Id registrationId) {
        return [SELECT summit__Status__c FROM summit__Summit_Events_Registration__c WHERE Id = :registrationId].summit__Status__c;
    }

    // A user who doesn't own the Registration, like the site guest user
    private static User invitee() {
        User u = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
            LastName = 'Declinetest',
            Alias = 'dcltest',
            Email = 'dcltest@example.invalid',
            Username = 'dcltest' + System.currentTimeMillis() + '@example.invalid',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Europe/Amsterdam'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
        }
        return u;
    }

    @IsTest
    static void declinesInvitationWithoutCreatingRecords() {
        summit__Summit_Events_Registration__c invitation = createRegistration('Invited');
        User testUser = invitee();

        System.runAs(testUser) {
            Test.startTest();
            InvitationDeclineController declineCtrl = openDeclinePage(getLinkParameter(invitation));
            Assert.isFalse(declineCtrl.eventNotFound);
            Assert.isTrue(declineCtrl.canDecline);
            Assert.areEqual('Invited', getStatus(invitation.Id), 'Opening the page must not change the registration');

            Assert.isNotNull(declineCtrl.declineInvitation());
            Test.stopTest();
        }

        Assert.areEqual('Declined', getStatus(invitation.Id));
        Assert.areEqual(1, [SELECT COUNT() FROM summit__Summit_Events_Registration__c], 'Decline must update the existing registration, not create one');

        System.runAs(testUser) {
            InvitationDeclineController reloadedCtrl = openDeclinePage(getLinkParameter(invitation));
            Assert.isTrue(reloadedCtrl.alreadyDeclined);
            Assert.isFalse(reloadedCtrl.canDecline);
        }
    }

    @IsTest
    static void repeatDeclineLeavesRegistrationDeclined() {
        summit__Summit_Events_Registration__c invitation = createRegistration('Declined');

        System.runAs(invitee()) {
            Test.startTest();
            InvitationDeclineController declineCtrl = openDeclinePage(getLinkParameter(invitation));
            Assert.isTrue(declineCtrl.alreadyDeclined);
            declineCtrl.declineInvitation();
            Test.stopTest();
        }

        Assert.areEqual('Declined', getStatus(invitation.Id));
    }

    @IsTest
    static void registeredInviteeCannotDecline() {
        summit__Summit_Events_Registration__c registration = createRegistration('Registered');

        System.runAs(invitee()) {
            Test.startTest();
            InvitationDeclineController declineCtrl = openDeclinePage(getLinkParameter(registration));
            Assert.isTrue(declineCtrl.notDeclinable);
            Assert.isFalse(declineCtrl.canDecline);
            declineCtrl.declineInvitation();
            Test.stopTest();
        }

        Assert.areEqual('Registered', getStatus(registration.Id));
    }

    @IsTest
    static void statusChangedAfterPageLoadIsNotDeclined() {
        summit__Summit_Events_Registration__c invitation = createRegistration('Invited');
        User testUser = invitee();
        InvitationDeclineController declineCtrl;

        System.runAs(testUser) {
            declineCtrl = openDeclinePage(getLinkParameter(invitation));
            Assert.isTrue(declineCtrl.canDecline);
        }

        // The invitee completes registration in another tab before confirming the decline
        invitation.summit__Status__c = 'Registered';
        update invitation;

        System.runAs(testUser) {
            Test.startTest();
            declineCtrl.declineInvitation();
            Test.stopTest();
        }

        Assert.areEqual('Registered', getStatus(invitation.Id));
    }

    @IsTest
    static void tamperedLinkShowsNotFound() {
        summit__Summit_Events_Registration__c invitation = createRegistration('Invited');

        System.runAs(invitee()) {
            Test.startTest();
            InvitationDeclineController declineCtrl = openDeclinePage(getLinkParameter(invitation) + 'TAMPER');
            Assert.isTrue(declineCtrl.eventNotFound);
            Assert.isFalse(declineCtrl.canDecline);
            declineCtrl.declineInvitation();
            Test.stopTest();
        }

        Assert.areEqual('Invited', getStatus(invitation.Id));
    }

    @IsTest
    static void missingLinkShowsNotFound() {
        System.runAs(invitee()) {
            Test.startTest();
            InvitationDeclineController declineCtrl = openDeclinePage(null);
            Assert.isTrue(declineCtrl.eventNotFound);
            Assert.isFalse(declineCtrl.canDecline);
            Test.stopTest();
        }
    }

    @IsTest
    static void tokenForAnotherObjectIsRejected() {
        Contact other = new Contact(LastName = 'Declinetest');
        insert other;
        String token = EncodingUtil.urlDecode(InvitationLink.encrypt(other.Id, null, null), 'UTF-8');

        Test.startTest();
        Assert.isNull(InvitationLink.decryptRegistrationId(token));
        Test.stopTest();
    }

    @IsTest
    static void linkRoundTripsForBulkInvitations() {
        summit__Summit_Events_Registration__c invitation = createRegistration('Invited');
        List<summit__Summit_Events_Registration__c> invitations = new List<summit__Summit_Events_Registration__c>();
        for (Integer i = 0; i < BULK_SIZE; i++) {
            invitations.add(invitation.clone(true, false, false, false));
        }

        Test.startTest();
        for (summit__Summit_Events_Registration__c registration : invitations) {
            InvitationLink.setEncryptedFields(registration);
        }
        Test.stopTest();

        Set<String> tokens = new Set<String>();
        for (summit__Summit_Events_Registration__c registration : invitations) {
            Assert.areEqual(invitation.Id, InvitationLink.decryptRegistrationId(getLinkParameter(registration)));
            tokens.add(getLinkParameter(registration));
        }
        Assert.areEqual(BULK_SIZE, tokens.size(), 'The managed IV must make every token different');
    }

    @IsTest
    static void noEncryptionKeyGivesNoLink() {
        summit__Summit_Events_Registration__c invitation = createRegistration('Invited');
        String token = getLinkParameter(invitation);
        summit__Summit_Events_Settings__c settings = summit__Summit_Events_Settings__c.getOrgDefaults();
        settings.summit__Cookie_Encryption_Key__c = null;
        update settings;

        Test.startTest();
        Assert.isNull(InvitationLink.encrypt(invitation.Id, null, null));
        Assert.isNull(InvitationLink.decryptRegistrationId(token));
        Test.stopTest();
    }

    // US-09: optional decline reason and comment

    private static summit__Summit_Events_Registration__c getDecline(Id registrationId) {
        return [
            SELECT summit__Status__c, Decline_Reason__c, Decline_Comment__c
            FROM summit__Summit_Events_Registration__c
            WHERE Id = :registrationId
        ];
    }

    private static summit__Summit_Events_Registration__c declineWith(String reason, String comment) {
        summit__Summit_Events_Registration__c invitation = createRegistration('Invited');

        System.runAs(invitee()) {
            Test.startTest();
            InvitationDeclineController declineCtrl = openDeclinePage(getLinkParameter(invitation));
            declineCtrl.declineReason = reason;
            declineCtrl.declineComment = comment;
            declineCtrl.declineInvitation();
            Test.stopTest();
        }
        return getDecline(invitation.Id);
    }

    @IsTest
    static void declineStoresReasonAndComment() {
        summit__Summit_Events_Registration__c declined = declineWith('Travelling', '  Abroad that week, good luck!  ');

        Assert.areEqual('Declined', declined.summit__Status__c);
        Assert.areEqual('Travelling', declined.Decline_Reason__c);
        Assert.areEqual('Abroad that week, good luck!', declined.Decline_Comment__c);
    }

    @IsTest
    static void declineWithoutReasonLeavesFieldsBlank() {
        summit__Summit_Events_Registration__c declined = declineWith('', '   ');

        Assert.areEqual('Declined', declined.summit__Status__c);
        Assert.isNull(declined.Decline_Reason__c);
        Assert.isNull(declined.Decline_Comment__c);
    }

    @IsTest
    static void unknownReasonIsDroppedButDeclineSucceeds() {
        summit__Summit_Events_Registration__c declined = declineWith('Tampered value', null);

        Assert.areEqual('Declined', declined.summit__Status__c);
        Assert.isNull(declined.Decline_Reason__c);
    }

    @IsTest
    static void longCommentIsCutToFieldLength() {
        Integer maxLength = Schema.SObjectType.summit__Summit_Events_Registration__c.fields.Decline_Comment__c.getLength();
        summit__Summit_Events_Registration__c declined = declineWith(null, 'x'.repeat(maxLength + 500));

        Assert.areEqual('Declined', declined.summit__Status__c);
        Assert.areEqual(maxLength, declined.Decline_Comment__c.length());
    }

    @IsTest
    static void repeatDeclineKeepsFirstReason() {
        summit__Summit_Events_Registration__c invitation = createRegistration('Declined');
        invitation.Decline_Reason__c = 'Other';
        invitation.Decline_Comment__c = 'First answer';
        update invitation;

        System.runAs(invitee()) {
            Test.startTest();
            InvitationDeclineController declineCtrl = openDeclinePage(getLinkParameter(invitation));
            declineCtrl.declineReason = 'Travelling';
            declineCtrl.declineComment = 'Second answer';
            declineCtrl.declineInvitation();
            Test.stopTest();
        }

        summit__Summit_Events_Registration__c declined = getDecline(invitation.Id);
        Assert.areEqual('Other', declined.Decline_Reason__c);
        Assert.areEqual('First answer', declined.Decline_Comment__c);
    }

    @IsTest
    static void registeredInviteeReasonIsNotStored() {
        summit__Summit_Events_Registration__c registration = createRegistration('Registered');

        System.runAs(invitee()) {
            Test.startTest();
            InvitationDeclineController declineCtrl = openDeclinePage(getLinkParameter(registration));
            declineCtrl.declineReason = 'Travelling';
            declineCtrl.declineInvitation();
            Test.stopTest();
        }

        summit__Summit_Events_Registration__c result = getDecline(registration.Id);
        Assert.areEqual('Registered', result.summit__Status__c);
        Assert.isNull(result.Decline_Reason__c);
    }

    @IsTest
    static void reasonOptionsStartWithPreferNotToSay() {
        summit__Summit_Events_Registration__c invitation = createRegistration('Invited');

        System.runAs(invitee()) {
            Test.startTest();
            List<SelectOption> options = openDeclinePage(getLinkParameter(invitation)).getDeclineReasonOptions();
            Test.stopTest();

            Assert.areEqual('', options[0].getValue());
            Assert.isTrue(options.size() > 1, 'The active Decline Reason values must be offered');
        }
    }
}
