@isTest
public with sharing class CookieConsentService_Test {
  @testSetup
  static void createTestData() {
    CookieConsentCategory__c cookieConsentCategory = CookieConsentTestUtilities.createCookieConsentCategory();
    Cookie__c cookie = CookieConsentTestUtilities.createCookie(cookieConsentCategory.Id);
    CookieConsentTestUtilities.createUser();
    CookieConsentTestUtilities.createStandardUser();
  }

  @isTest
  static void testVerifyBrowserId_guestUser() {
    List<User> users = [SELECT Id FROM User WHERE Username = 'test@cookieconsent.com' LIMIT 1];
    User guestUser = (users.size() == 1) ? users.get(0) : null;

    Test.startTest();

    Boolean result = null;
    System.runAs(guestUser) {
      result = CookieConsentService.verifyBrowserId('123456789');
    }

    Test.stopTest();

    System.assert(!result);
  }

  @isTest
  static void testVerifyBrowserId_standardUser() {
    List<User> users = [SELECT Id FROM User WHERE Username = 'standard@cookieconsent.com' LIMIT 1];
    User standardUser = (users.size() == 1) ? users.get(0) : null;

    Test.startTest();

    Boolean result = null;
    System.runAs(standardUser) {
      result = CookieConsentService.verifyBrowserId('123456789');
    }

    Test.stopTest();

    System.assert(!result);
  }

  @isTest
  static void testGetCookieData() {
    List<User> users = [SELECT Id FROM User WHERE Username = 'standard@cookieconsent.com' LIMIT 1];
    User standardUser = (users.size() == 1) ? users.get(0) : null;

    Test.startTest();

    List<Map<String, Object>> result = new List<Map<String, Object>>();
    System.runAs(standardUser) {
      result = CookieConsentService.getCookieData();
    }

    Test.stopTest();

    System.assert(result.size() == 1);
  }

  @isTest
  static void testVerifyBrowserId_guestUserWithIndividual() {
    Individual individual = CookieConsentTestUtilities.createIndividual();

    List<User> users = [SELECT Id FROM User WHERE Username = 'test@cookieconsent.com' LIMIT 1];
    User guestUser = (users.size() == 1) ? users.get(0) : null;

    Test.startTest();

    Boolean result = null;
    System.runAs(guestUser) {
      result = CookieConsentService.verifyBrowserId('123456789');
    }

    Test.stopTest();

    System.assert(!result);
  }

  @isTest
  static void testVerifyBrowserId_guestUserWithIndividualAndPreferences() {
    List<CookieConsentCategory__c> cookieConsentCategories = [SELECT Id FROM CookieConsentCategory__c LIMIT 1];
    CookieConsentCategory__c cookieConsentCategory = (cookieConsentCategories.size() == 1) ? cookieConsentCategories.get(0) : null;
    Individual individual = CookieConsentTestUtilities.createIndividual();

    Test.startTest();

    List<User> users = [SELECT Id FROM User WHERE Username = 'test@cookieconsent.com' LIMIT 1];
    User guestUser = (users.size() == 1) ? users.get(0) : null;

    List<Map<String, String>> cookiePreferences = new List<Map<String, String>>();

    Map<String, String> preferenceRow = new Map<String, String>();

    preferenceRow.put('authorizationFormId', cookieConsentCategory.Id);
    preferenceRow.put('value', 'true');

    cookiePreferences.add(preferenceRow);

    Boolean createRecords = CookieConsentServiceGuestHelper.createCookieConsentRecords('123456789', cookiePreferences);

    Boolean result = null;
    System.runAs(guestUser) {
      result = CookieConsentService.verifyBrowserId('123456789');
    }

    Test.stopTest();

    System.assert(result, 'consent records were not found');
  }

  @isTest
  static void testGetCookiesToDelete_guestUserWithIndividualAndPreferences() {
    List<CookieConsentCategory__c> cookieConsentCategories = [SELECT Id FROM CookieConsentCategory__c LIMIT 1];
    CookieConsentCategory__c cookieConsentCategory = (cookieConsentCategories.size() == 1) ? cookieConsentCategories.get(0) : null;
    Individual individual = CookieConsentTestUtilities.createIndividual();

    Test.startTest();

    List<User> users = [SELECT Id FROM User WHERE Username = 'test@cookieconsent.com' LIMIT 1];
    User guestUser = (users.size() == 1) ? users.get(0) : null;

    List<Map<String, String>> cookiePreferences = new List<Map<String, String>>();

    Map<String, String> preferenceRow = new Map<String, String>();

    preferenceRow.put('authorizationFormId', cookieConsentCategory.Id);
    preferenceRow.put('value', 'true');

    cookiePreferences.add(preferenceRow);

    Boolean createRecords = CookieConsentServiceGuestHelper.createCookieConsentRecords('123456789', cookiePreferences);

    List<String> cookiesToDelete = new List<String>();
    System.runAs(guestUser) {
      cookiesToDelete = CookieConsentServiceGuestHelper.getCookiesToDelete('123456789');
    }

    Test.stopTest();

    System.assert(cookiesToDelete.size() == 0);
  }
}