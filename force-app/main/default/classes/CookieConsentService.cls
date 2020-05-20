public with sharing class CookieConsentService {
  /**
   * verifyBrowserId allows you to check to see if there is a browserId associated to an individual object record
   * @param browserId - the unique browser Id passed from the community
   */
  @AuraEnabled
  public static Boolean verifyBrowserId(String browserId) {
    String userType = UserInfo.getUserType();
    Id userId = UserInfo.getUserId();
    Id individualId = null;
    Individual individual = getIndividualByBrowserId(browserId);
    if (individual != null) {
      individualId = individual.Id;
    } else {
      if (userType != 'Guest' && userType != 'Standard') {
        User loggedInUser = getLoggedInUserDetails(userId);
        individualId = loggedInUser.IndividualId;
        if (individualId == null) {
          individualId = createIndividualRecord(userId, browserId);
        }
      } else {
        individualId = createIndividualRecord(null, browserId);
      }
    }
    if (individualId != null) {
      Boolean cookieConsentGranted = verifyCookieConsentGranted(individualId);
      return cookieConsentGranted;
    }
    return false;
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
      WITH SECURITY_ENFORCED
    ]) {
      categoryIds.add(consent.cookiecon__CookieConsentCategory__c);
    }

    List<String> cookieNames = new List<String>();
    for (cookiecon__Cookie__c cookie : [SELECT Id, Name FROM cookiecon__Cookie__c WHERE cookiecon__CookieConsentCategory__c IN :categoryIds WITH SECURITY_ENFORCED]) {
      cookieNames.add(cookie.Name);
    }
    return cookieNames;
  }

  /**
   * getIndividualByUserID will get the logged in userId and check to see if an individual has been created
   * @param browserId - the unique browser Id passed from the community
   */
  public static Individual getIndividualByBrowserId(String browserId) {
    List<Individual> individuals = [SELECT Id, BrowserId__c FROM Individual WHERE BrowserId__c = :browserId WITH SECURITY_ENFORCED LIMIT 1];
    Individual individual = (individuals.size() == 1) ? individuals.get(0) : null;
    return individual;
  }

  /**
   * getIndividualByUserID will get the logged in userId and check to see if an individual has been created
   * @param userId - the userId of the logged in user
   */
  public static User getLoggedInUserDetails(Id userId) {
    List<User> users = [SELECT FirstName, LastName, IndividualId FROM User WHERE Id = :userId WITH SECURITY_ENFORCED LIMIT 1];
    User user = (users.size() == 1) ? users.get(0) : null;
    return user;
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
      WHERE cookiecon__CookieConsentCategory__c IN :authFormIds AND cookiecon__ConsentGiverId__c = :individualId
      WITH SECURITY_ENFORCED
    ];
    if (authorizationFormConsents.size() >= cookieConsentCategories.size()) {
      return true;
    }
    return false;
  }

  /**
   * getCookieData is used to get all of the cookies to display to the user in the consent modal.
   * Currently this does NOT support more than the 3 initial consent definitions.
   */
  @AuraEnabled(Cacheable=true)
  public static List<Map<String, Object>> getCookieData() {
    Id currentUserId = UserInfo.getUserId();
    List<cookiecon__CookieConsentCategory__c> cookieConsentCategories = getCookieConsentCategories();
    List<Map<String, Object>> finalCookieData = new List<Map<String, Object>>();
    for (cookiecon__CookieConsentCategory__c cookieConsentCategory : cookieConsentCategories) {
      List<cookiecon__Cookie__c> relatedCookies = getRelatedCookies(cookieConsentCategory.Id);
      Map<String, Object> sectionItem = new Map<String, Object>();
      sectionItem.put('SectionName', cookieConsentCategory.Name);
      sectionItem.put('SectionDescription', cookieConsentCategory.cookiecon__Description__c);
      sectionItem.put('RelatedAuthorizationFormId', cookieConsentCategory.Id);
      sectionItem.put('Mandatory', cookieConsentCategory.cookiecon__Manditory__c);
      sectionItem.put('DefaultValue', cookieConsentCategory.cookiecon__DefaultValue__c);
      sectionItem.put('AdditionalInformation', cookieConsentCategory.cookiecon__AdditionalInformation__c);
      sectionItem.put('SectionCookies', relatedCookies);
      if (finalCookieData.isEmpty()) {
        sectionItem.put('ShowSection', true);
        sectionItem.put('SectionIcon', 'utility:chevrondown');
      } else {
        sectionItem.put('ShowSection', false);
        sectionItem.put('SectionIcon', 'utility:chevronright');
      }
      finalCookieData.add(sectionItem);
    }
    return finalCookieData;
  }

  /**
   * createCookieConsentRecords is used to confirm authorization for cookie consent against the browserId
   * @param browserId - the unique browser Id passed from the community
   */
  @AuraEnabled
  public static boolean createCookieConsentRecords(String browserId, List<Map<String, String>> cookiePreferences) {
    Individual individual = getIndividualByBrowserId(browserId);
    List<cookiecon__CookieConsent__c> createdConsentRecords = createAuthorizationFormConsentRecords(individual.Id, cookiePreferences);
    if (createdConsentRecords != null) {
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
    Individual newIndividual = new Individual(LastName = browserId, BrowserId__c = browserId);
    newIndividuals.add(newIndividual);
    SObjectAccessDecision sanitisedRecords = Security.stripInaccessible(AccessType.CREATABLE, newIndividuals);
    insert sanitisedRecords.getRecords();
    return sanitisedRecords.getRecords()[0].Id;
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
        WITH SECURITY_ENFORCED
        LIMIT 1
      ];
      cookiecon__CookieConsentCategory__c cookieConsentCategory = (cookieConsentCategories.size() == 1) ? cookieConsentCategories.get(0) : null;
      cookiecon__CookieConsent__c newAuthorizationFormConsentRecord = new cookiecon__CookieConsent__c();
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
    SObjectAccessDecision sanitisedRecords = Security.stripInaccessible(AccessType.CREATABLE, authorizationFormConsentRecords);
    insert sanitisedRecords.getRecords();
    return sanitisedRecords.getRecords();
  }

  /**
   * @description - Reusable SOQL Queries Cookie Records
   */
  public static List<cookiecon__CookieConsentCategory__c> getCookieConsentCategories() {
    List<cookiecon__CookieConsentCategory__c> cookieConsentCategories = [
      SELECT cookiecon__DefaultValue__c, cookiecon__Description__c, cookiecon__Manditory__c, cookiecon__AdditionalInformation__c, Id, Name
      FROM cookiecon__CookieConsentCategory__c
      WITH SECURITY_ENFORCED
    ];
    return cookieConsentCategories;
  }

  public static List<cookiecon__Cookie__c> getRelatedCookies(Id cookieConsentCategoryId) {
    List<cookiecon__Cookie__c> relatedCookies = [
      SELECT cookiecon__Description__c, Id, Name
      FROM cookiecon__Cookie__c
      WHERE cookiecon__CookieConsentCategory__c = :cookieConsentCategoryId
      WITH SECURITY_ENFORCED
    ];
    return relatedCookies;
  }
}
