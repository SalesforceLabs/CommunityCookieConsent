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
    Individual individual = CookieConsentServiceGuestHelper.getIndividualByBrowserId(browserId);
    if (individual != null) {
      individualId = individual.Id;
    } else {
      if (userType != 'Guest' && userType != 'Standard') {
        User loggedInUser = getLoggedInUserDetails(userId);
        individualId = loggedInUser.IndividualId;
        if (individualId == null) {
          individualId = CookieConsentServiceGuestHelper.createIndividualRecord(userId, browserId);
        }
      } else {
        individualId = CookieConsentServiceGuestHelper.createIndividualRecord(null, browserId);
      }
    }
    if (individualId != null) {
      Boolean cookieConsentGranted = CookieConsentServiceGuestHelper.verifyCookieConsentGranted(individualId);
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
   * @param userId - the userId of the logged in user
   */
  public static User getLoggedInUserDetails(Id userId) {
    List<User> users = [SELECT FirstName, LastName, IndividualId FROM User WHERE Id = :userId LIMIT 1];
    User user = (users.size() == 1) ? users.get(0) : null;
    return user;
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
    Individual individual = CookieConsentServiceGuestHelper.getIndividualByBrowserId(browserId);
    List<cookiecon__CookieConsent__c> createdConsentRecords = CookieConsentServiceGuestHelper.createAuthorizationFormConsentRecords(individual.Id, cookiePreferences);
    if (createdConsentRecords != null) {
      return true;
    }
    return false;
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
