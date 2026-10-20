/**
 * Reads and writes the encrypted registration string that the Summit Events package uses for its cancel link
 * (summit__Encrypted_Registration_Id_1__c / _2__c), so the decline link can reuse it (US-08).
 *
 * The package classes that do this (SummitEventsShared.encryptString / decryptString) are public, not global,
 * so they can't be called from outside the package. This class mirrors their format: AES256 with a managed IV,
 * keyed by summit__Summit_Events_Settings__c.summit__Cookie_Encryption_Key__c, then base64 and URL-encoded.
 * If a package upgrade changes that format, these links stop working: after an upgrade, check that a real
 * package cancel-link token still opens the decline page.
 *
 * The package only writes the encrypted fields when a public registration completes. Invitation Registrations
 * created by automation need setEncryptedFields() before a decline link can be sent.
 */
public with sharing class InvitationLink {
    private static final Integer FIELD_LENGTH = 255;

    // Same JSON shape as the package cookie, so tokens are interchangeable with package cancel links
    private class Payload {
        public String audience;
        public String instanceId;
        public String eventId;
        public String registrationId;
        public String dt;
        public String valid;
    }

    // Returns the URL-encoded string, the form the package stores in the encrypted fields
    public static String encrypt(Id registrationId, Id instanceId, Id eventId) {
        Blob key = getKey();
        if (key == null || registrationId == null) {
            return null;
        }
        Payload payload = new Payload();
        payload.audience = '';
        payload.instanceId = instanceId;
        payload.eventId = eventId;
        payload.registrationId = registrationId;
        payload.dt = String.valueOf(Datetime.now());
        payload.valid = 'false';
        Blob encrypted = Crypto.encryptWithManagedIV('AES256', key, Blob.valueOf(JSON.serialize(payload)));
        return EncodingUtil.urlEncode(EncodingUtil.base64Encode(encrypted), 'UTF-8');
    }

    // Splits the string over the two package fields the way SummitEventsConfirmationController does
    public static void setEncryptedFields(summit__Summit_Events_Registration__c registration) {
        String encrypted = encrypt(registration.Id, registration.summit__Event_Instance__c, registration.summit__Event__c);
        if (encrypted == null) {
            return;
        }
        registration.summit__Encrypted_Registration_Id_1__c = encrypted.left(FIELD_LENGTH);
        registration.summit__Encrypted_Registration_Id_2__c = encrypted.length() > FIELD_LENGTH ? encrypted.substring(FIELD_LENGTH) : null;
    }

    /**
     * Takes the eventInfo parameter as Visualforce returns it (already URL-decoded once by the platform).
     * Returns null for a blank, tampered or foreign token, so callers can show one generic "not found" message.
     */
    public static Id decryptRegistrationId(String token) {
        Blob key = getKey();
        if (String.isBlank(token) || key == null) {
            return null;
        }
        try {
            Blob decrypted = Crypto.decryptWithManagedIV('AES256', key, EncodingUtil.base64Decode(token));
            Payload payload = (Payload) JSON.deserialize(decrypted.toString(), Payload.class);
            Id decryptedId = Id.valueOf(payload.registrationId);
            return decryptedId.getSobjectType() == summit__Summit_Events_Registration__c.SObjectType ? decryptedId : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static Blob getKey() {
        String key = summit__Summit_Events_Settings__c.getOrgDefaults().summit__Cookie_Encryption_Key__c;
        return String.isBlank(key) ? null : Blob.valueOf(key);
    }
}
