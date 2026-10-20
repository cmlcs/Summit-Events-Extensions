/**
 * Controller for the InvitationDecline page (US-08): an unauthenticated invitee declines a Gala invitation
 * without completing the registration form.
 *
 * Security model, following the package's SummitEventsCancelReviewController:
 * - The Registration is identified by the encrypted string in the URL (see InvitationLink), never by a plain Id.
 * - Loading the page changes nothing. Email link scanners open links, so only the confirm button (a POST,
 *   protected by the Visualforce view state) can decline.
 * - The status is re-read before the update, and only summit__Status__c is written.
 */
public with sharing class InvitationDeclineController {
    public static final String DECLINED_STATUS = 'Declined';
    // Only invitations can be declined. Registered or in-progress registrants use the package cancel link instead.
    public static final Set<String> DECLINABLE_STATUSES = new Set<String>{ 'Invited' };
    // Templates shipped in the package; any other value is a template page in this org
    private static final Set<String> PACKAGE_TEMPLATES = new Set<String>{ 'GeneralSLDS', 'crowncollege2020', 'OPUSTemplate2018', 'CastorTemplate2017' };

    public summit__Summit_Events_Registration__c eventRegistration { get; private set; }
    public summit__Summit_Events__c eventPage { get; private set; }
    public String templateSelected { get; private set; }
    public Boolean eventNotFound { get; private set; }
    public Boolean canDecline { get; private set; }
    public Boolean alreadyDeclined { get; private set; }
    public Boolean notDeclinable { get; private set; }
    private String eventParameter;
    private Id registrationId;

    public InvitationDeclineController() {
        eventParameter = ApexPages.currentPage().getParameters().get('eventInfo');
        eventNotFound = true;
        canDecline = false;
        alreadyDeclined = false;
        notDeclinable = false;
        eventRegistration = new summit__Summit_Events_Registration__c();
        eventPage = new summit__Summit_Events__c();
        templateSelected = getTemplate(null);

        Id decryptedId = InvitationLink.decryptRegistrationId(eventParameter);
        if (decryptedId == null) {
            return;
        }
        RegistrationAccess access = new RegistrationAccess();
        summit__Summit_Events_Registration__c registration = access.getRegistration(decryptedId);
        if (registration == null) {
            return;
        }

        eventRegistration = registration;
        eventPage = access.getEvent(registration.summit__Event__c);
        registrationId = registration.Id;
        templateSelected = getTemplate(eventPage.summit__Template__c);
        eventNotFound = false;
        setDeclineState(registration.summit__Status__c);
    }

    public PageReference declineInvitation() {
        if (registrationId != null) {
            RegistrationAccess access = new RegistrationAccess();
            // Re-read the status so a registration completed in another tab can't be declined from a stale page
            summit__Summit_Events_Registration__c currentRegistration = access.getRegistration(registrationId);
            if (currentRegistration != null && DECLINABLE_STATUSES.contains(currentRegistration.summit__Status__c)) {
                if (!access.updateStatus(registrationId, DECLINED_STATUS)) {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'We could not record your response. Please try again or contact the event organizer.'));
                    return null;
                }
            }
        }
        PageReference pg = Page.InvitationDecline;
        pg.getParameters().put('eventInfo', eventParameter);
        pg.setRedirect(true);
        return pg;
    }

    private void setDeclineState(String status) {
        alreadyDeclined = status == DECLINED_STATUS;
        canDecline = DECLINABLE_STATUSES.contains(status);
        notDeclinable = !alreadyDeclined && !canDecline;
    }

    // Mirrors the package's SummitEventsShared.getTemplate, which is not callable from outside the package
    private static String getTemplate(String templateName) {
        if (String.isBlank(templateName)) {
            return 'summit__GeneralSLDS';
        }
        return PACKAGE_TEMPLATES.contains(templateName) ? 'summit__' + templateName : templateName;
    }

    /**
     * The guest user does not own the Registration, so reads and the status update run without sharing and in
     * system mode. The caller has already proved access with the encrypted link; only the status is written.
     */
    private without sharing class RegistrationAccess {

        public summit__Summit_Events_Registration__c getRegistration(Id regId) {
            List<summit__Summit_Events_Registration__c> registrations = [
                SELECT Id, summit__Status__c, summit__Event__c, summit__Event_Instance_Title__c, summit__Event_Instance_Date_Time_Formatted__c
                FROM summit__Summit_Events_Registration__c
                WHERE Id = :regId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            return registrations.isEmpty() ? null : registrations[0];
        }

        public summit__Summit_Events__c getEvent(Id eventId) {
            List<summit__Summit_Events__c> events = [
                SELECT Id, summit__Event_Name__c, summit__Event_description__c, summit__Event_Footer__c, summit__Template__c,
                    summit__Event_Home_Link_URL__c, summit__Event_Home_Link_Title__c, summit__Audience__c
                FROM summit__Summit_Events__c
                WHERE Id = :eventId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            return events.isEmpty() ? new summit__Summit_Events__c() : events[0];
        }

        public Boolean updateStatus(Id regId, String newStatus) {
            Database.SaveResult result = Database.update(
                new summit__Summit_Events_Registration__c(Id = regId, summit__Status__c = newStatus),
                false,
                AccessLevel.SYSTEM_MODE
            );
            if (!result.isSuccess()) {
                System.debug(LoggingLevel.ERROR, 'Invitation decline failed for ' + regId + ': ' + result.getErrors());
            }
            return result.isSuccess();
        }
    }
}
