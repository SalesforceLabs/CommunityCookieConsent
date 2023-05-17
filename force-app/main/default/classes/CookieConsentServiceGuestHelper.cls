public without sharing class CookieConsentServiceGuestHelper {
  /**
   * getIndividualByUserID will get the logged in userId and check to see if an individual has been created
   * @param browserId - the unique browser Id passed from the community
   */
  public static Individual getIndividualByBrowserId(String browserId) {
    List<Individual> individuals = [SELECT Id, cookiecon__BrowserId__c FROM Individual WHERE cookiecon__BrowserId__c = :browserId LIMIT 1];
    Individual individual = (individuals.size() == 1) ? individuals.get(0) : null;
    return individual;
  }

  /**
   * @description - createAuthorizationFormConsentRecords is used to create the consent records that are associated to a positive agreement to cookies.
   * @param individualId - the individualId associated to the user that is accepting the terms
   * @param relatedAuthorizationFormNames - the list of authorization form records that is being used to create the consent records
   */
  public static List<cookiecon__CookieConsent__c> createAuthorizationFormConsentRecords(Id individualId, List<Map<String, String>> cookiePreferences) {
    List<cookiecon__CookieConsent__c> authorizationFormConsentRecords = new List<cookiecon__CookieConsent__c>();
    for (Map<String, String> cookiePreference : cookiePreferences) {
      List<cookiecon__CookieConsentCategory__c> cookieConsentCategories = [
        SELECT Id, Name
        FROM cookiecon__CookieConsentCategory__c
        WHERE Id = :cookiePreference.get('authorizationFormId')
        //WITH SECURITY_ENFORCED
        LIMIT 1
      ];
      CookieConsentCategory__c cookieConsentCategory = (cookieConsentCategories.size() == 1) ? cookieConsentCategories.get(0) : null;
      CookieConsent__c newAuthorizationFormConsentRecord = new CookieConsent__c();
      newAuthorizationFormConsentRecord.Name = cookieConsentCategory.Name;
      newAuthorizationFormConsentRecord.cookiecon__CookieConsentCategory__c = cookieConsentCategory.Id;
      newAuthorizationFormConsentRecord.cookiecon__ConsentCapturedSource__c = 'Salesforce Community';
      newAuthorizationFormConsentRecord.cookiecon__ConsentCapturedSourceType__c = 'Web';
      newAuthorizationFormConsentRecord.cookiecon__ConsentGiverId__c = individualId;
      if (cookiePreference.get('value') == 'true') {
        newAuthorizationFormConsentRecord.cookiecon__Status__c = 'Agreed';
      } else if (cookiePreference.get('value') == 'false') {
        newAuthorizationFormConsentRecord.cookiecon__Status__c = 'Declined';
      }
      authorizationFormConsentRecords.add(newAuthorizationFormConsentRecord);
    }
    insert authorizationFormConsentRecords;
    return authorizationFormConsentRecords;
    /*
    SObjectAccessDecision sanitisedRecords = Security.stripInaccessible(AccessType.CREATABLE, authorizationFormConsentRecords);
    insert sanitisedRecords.getRecords();
    return sanitisedRecords.getRecords();
    */
  }

  /**
   * verifyCookieConsentGranted is called  by verifyCookieConsent if an Individual has been matched to the browserId
   * It gets a list of the available cookie consent definitions, the related authorization form names and then queries a
   * list of valid authorization form consent records that fit those definitions.
   * @param individualId - the individual record associated to the browserId
   */
  public static Boolean verifyCookieConsentGranted(Id individualId) {
    List<cookiecon__CookieConsentCategory__c> cookieConsentCategories = getCookieConsentCategories();
    Set<Id> authFormIds = (new Map<Id, SObject>(cookieConsentCategories)).keySet();
    List<cookiecon__CookieConsent__c> authorizationFormConsents = [
      SELECT Id
      FROM cookiecon__CookieConsent__c
      WHERE CookieConsentCategory__c IN :authFormIds AND cookiecon__ConsentGiverId__c = :individualId
      //WITH SECURITY_ENFORCED
    ];
    if (authorizationFormConsents.size() >= cookieConsentCategories.size()) {
      return true;
    }
    return false;
  }

  /**
   * createIndividualRecord is used to create an individual for a logged in user or browserId
   * @param userId - the userId of the logged in user
   * @param browserId - the unique browser Id passed from the community
   */
  public static Id createIndividualRecord(Id userId, String browserId) {
    List<Individual> newIndividuals = new List<Individual>();
    Individual newIndividual = new Individual(LastName = browserId, cookiecon__BrowserId__c = browserId);
    newIndividuals.add(newIndividual);
    /*
    SObjectAccessDecision sanitisedRecords = Security.stripInaccessible(AccessType.CREATABLE, newIndividuals);
    insert sanitisedRecords.getRecords();
    return sanitisedRecords.getRecords()[0].Id;
    */
    insert newIndividual;
    return newIndividual.Id;
  }

  /**
   * @description - Reusable SOQL Queries Cookie Records
   */
  public static List<cookiecon__CookieConsentCategory__c> getCookieConsentCategories() {
    List<cookiecon__CookieConsentCategory__c> cookieConsentCategories = [
      SELECT cookiecon__DefaultValue__c, cookiecon__Description__c, cookiecon__Manditory__c, cookiecon__AdditionalInformation__c, Id, Name
      FROM cookiecon__CookieConsentCategory__c
      ORDER BY Name
    ];
    return cookieConsentCategories;
  }

  public static List<cookiecon__Cookie__c> getRelatedCookies(Id cookieConsentCategoryId) {
    List<cookiecon__Cookie__c> relatedCookies = [SELECT cookiecon__Description__c, Id, Name FROM cookiecon__Cookie__c WHERE cookiecon__CookieConsentCategory__c = :cookieConsentCategoryId];
    return relatedCookies;
  }

  /**
   * getIndividualByUserID will get the logged in userId and check to see if an individual has been created
   * @param userId - the userId of the logged in user
   */
  public static User getLoggedInUserDetails(Id userId) {
    List<User> users = [SELECT FirstName, LastName, IndividualId FROM User WHERE Id = :userId LIMIT 1];
    User user = (users.size() == 1) ? users.get(0) : null;
    return user;
  }

  /**
   * @description - Get cookies from the user if they've been rejected by the person accessing the community.
   * @param browserId - the unique browser Id passed from the community
   * @return List<String> of Cookies
   */

  @AuraEnabled
  public static List<String> getCookiesToDelete(String browserId) {
    Set<Id> categoryIds = new Set<Id>();
    for (cookiecon__CookieConsent__c consent : [
      SELECT cookiecon__CookieConsentCategory__c
      FROM cookiecon__CookieConsent__c
      WHERE cookiecon__ConsentGiverId__c IN (SELECT Id FROM Individual WHERE cookiecon__BrowserId__c = :browserId) AND cookiecon__Status__c = 'Declined'
    ]) {
      categoryIds.add(consent.CookieConsentCategory__c);
    }

    List<String> cookieNames = new List<String>();
    for (cookiecon__Cookie__c cookie : [SELECT Id, Name FROM cookiecon__Cookie__c WHERE cookiecon__CookieConsentCategory__c IN :categoryIds]) {
      cookieNames.add(cookie.Name);
    }
    return cookieNames;
  }

  /**
   * createCookieConsentRecords is used to confirm authorization for cookie consent against the browserId
   * @param browserId - the unique browser Id passed from the community
   */
  @AuraEnabled
  public static boolean createCookieConsentRecords(String browserId, List<Map<String, String>> cookiePreferences) {
    Individual individual = CookieConsentServiceGuestHelper.getIndividualByBrowserId(browserId);
    List<CookieConsent__c> createdConsentRecords = CookieConsentServiceGuestHelper.createAuthorizationFormConsentRecords(individual.Id, cookiePreferences);
    if (createdConsentRecords != null) {
      return true;
    }
    return false;
  }
}