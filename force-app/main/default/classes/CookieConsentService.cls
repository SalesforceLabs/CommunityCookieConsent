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
        User loggedInUser = CookieConsentServiceGuestHelper.getLoggedInUserDetails(userId);
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
   * getCookieData is used to get all of the cookies to display to the user in the consent modal.
   * Currently this does NOT support more than the 3 initial consent definitions.
   */
  @AuraEnabled(Cacheable=true)
  public static List<Map<String, Object>> getCookieData() {
    Id currentUserId = UserInfo.getUserId();
    List<CookieConsentCategory__c> cookieConsentCategories = CookieConsentServiceGuestHelper.getCookieConsentCategories();
    List<Map<String, Object>> finalCookieData = new List<Map<String, Object>>();
    for (CookieConsentCategory__c cookieConsentCategory : cookieConsentCategories) {
      List<Cookie__c> relatedCookies = CookieConsentServiceGuestHelper.getRelatedCookies(cookieConsentCategory.Id);
      Map<String, Object> sectionItem = new Map<String, Object>();
      sectionItem.put('SectionName', cookieConsentCategory.Name);
      sectionItem.put('SectionDescription', cookieConsentCategory.Description__c);
      sectionItem.put('RelatedAuthorizationFormId', cookieConsentCategory.Id);
      sectionItem.put('Mandatory', cookieConsentCategory.Manditory__c);
      sectionItem.put('DefaultValue', cookieConsentCategory.DefaultValue__c);
      sectionItem.put('AdditionalInformation', cookieConsentCategory.AdditionalInformation__c);
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


}