@isTest
public with sharing class CookieConsentTestUtilities {

    @future
    public static void createUser(){

        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Customer Community Profile' LIMIT 1];
        Profile profile = (profiles.size() == 1) ? profiles.get(0) : null;

        User user = new User(Username = 'test@cookieconsent.com', FirstName = 'First', LastName = 'Last', Email = 'example@example.com', ProfileId = profile.Id, CompanyName = 'Test', Title ='Title', Alias = 'alias', TimeZoneSidKey = 'America/Los_Angeles', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US');

        insert user;

        List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name = 'Cookie_Consent_Guest_User' LIMIT 1];
        PermissionSet permissionSet = (permissionSets.size() == 1) ? permissionSets.get(0) : null;

        PermissionSetAssignment permissionSetAssignment = new PermissionSetAssignment(PermissionSetId = permissionSet.Id, AssigneeId = user.Id);

        insert permissionSetAssignment;

    }

    @future
    public static void createStandardUser(){

        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        Profile profile = (profiles.size() == 1) ? profiles.get(0) : null;

        User user = new User(Username = 'standard@cookieconsent.com', FirstName = 'First', LastName = 'Last', Email = 'example@example.com', ProfileId = profile.Id, CompanyName = 'Test', Title ='Title', Alias = 'alias', TimeZoneSidKey = 'America/Los_Angeles', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US');

        insert user;

        List<PermissionSet> permissionSets = [SELECT Id FROM PermissionSet WHERE Name = 'Cookie_Consent_Guest_User' LIMIT 1];
        PermissionSet permissionSet = (permissionSets.size() == 1) ? permissionSets.get(0) : null;

        PermissionSetAssignment permissionSetAssignment = new PermissionSetAssignment(PermissionSetId = permissionSet.Id, AssigneeId = user.Id);

        insert permissionSetAssignment;

    }

    public static cookiecon__CookieConsentCategory__c createCookieConsentCategory(){

        cookiecon__CookieConsentCategory__c cookieConsentCategory = new cookiecon__CookieConsentCategory__c(Name = 'Test', cookiecon__Description__c = 'Description', cookiecon__DefaultValue__c = true, cookiecon__Manditory__c = true, cookiecon__AdditionalInformation__c = 'Test');

        insert cookieConsentCategory;

        return cookieConsentCategory;

    }

    public static cookiecon__Cookie__c createCookie(Id categoryId){

        cookiecon__Cookie__c cookie = new cookiecon__Cookie__c(Name = 'Test', cookiecon__Description__c = 'Test', cookiecon__CookieConsentCategory__c = categoryId);

        insert cookie;

        return cookie;

    }

    public static Individual createIndividual() {

        Individual newIndividual = new Individual(FirstName = 'Test', LastName = 'Test', cookiecon__BrowserId__c = '123456789');

        insert newIndividual;

        return newIndividual;

    }


}