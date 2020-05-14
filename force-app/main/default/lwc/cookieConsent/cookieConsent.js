/**
 * Created by stephan.garcia on 2020-03-10.
 */

import { LightningElement, track, api } from "lwc";
import getCookieData from "@salesforce/apex/CookieConsentService.getCookieData";
import createCookieConsentRecords from "@salesforce/apex/CookieConsentService.createCookieConsentRecords";
import verifyBrowserId from "@salesforce/apex/CookieConsentService.verifyBrowserId";
import getCookiesToDrop from "@salesforce/apex/CookieConsentService.getCookiesToDrop";

export default class CookieConsent extends LightningElement {
  showCookieDialog;
  @track cookieData;
  browserId;
  cookiePreferences = [];
  loading = true;
  browserIdChecked = 0;
  preview;

  @api displayType = "footer";
  @api headingLabel = "Manage Cookies";
  @api instructions = "Cookie Instructions";
  @api informationButtonLabel = "View Privacy Policy";
  @api informationButtonLink = "https://www.salesforce.com";
  @api viewCookiesLabel = "View Cookies";
  @api viewCookiesLink = "https://www.salesforce.com";
  @api confirmButtonLabel = "Confirm Preferences";
  @api rejectButtonLabel = "Leave Site";

  @api cookieFooterBackgroundColor = "rgb(0,0,0)";
  @api cookieFooterLinkColor = "rgb(250, 250, 250)";
  @api cookieFooterTextColor = "rgb(250, 250, 250)";

  connectedCallback() {
    let preview = this.checkIfInPreview();
    this.getBrowserIdCookie(preview);
  }

  checkIfInPreview() {
    let urlToCheck = window.location.href;
    if (!urlToCheck) {
      urlToCheck = window.location.hostname;
    }
    urlToCheck = urlToCheck.toLowerCase();
    return urlToCheck.indexOf("sitepreview") >= 0 || urlToCheck.indexOf("livepreview") >= 0;
  }

  getBrowserIdCookie(preview) {
    this.browserIdChecked++;
    let cookieName = "BrowserId";
    let cookieValue = document.cookie.match("(^|;) ?" + cookieName + "=([^;]*)(;|$)");
    this.browserId = cookieValue ? cookieValue[2] : null;

    if (this.browserId) {
      this.verifyBrowserId();
    } else if (preview === false) {
      this.getBrowserIdSecCookie();
    } else if (preview === true) {
      this.preview = true;
    }
  }

  getBrowserIdSecCookie(preview) {
    this.browserIdChecked++;
    let cookieName = "BrowserId_sec";
    let cookieValue = document.cookie.match("(^|;) ?" + cookieName + "=([^;]*)(;|$)");
    this.browserId = cookieValue ? cookieValue[2] : null;

    if (this.browserId) {
      this.verifyBrowserId();
    } else if (preview === false) {
      this.getBrowserIdCookie();
    }
  }

  getCookieSectionsAndData() {
    getCookieData()
      .then(data => {
        this.cookieData = [...data];

        this.setStartingCookiePreferences(data);
        this.loading = false;
      })
      .catch(error => {});
  }

  getCookiesAndDropThem() {
    getCookiesToDrop({ browserId: this.browserId })
      .then(data => {
        this.dropCookies(data);
      })
      .catch(error => {});
  }

  dropCookies(cookies) {
    for (let i = 0, len = cookies.length; i < len; i++) {
      let cookieString = cookies[i] + "=; expires=Thu, 01 Jan 1970 00:00:01 GMT;path=/;";
      let cookieStrings = cookies[i] + "=; expires=Thu, 01 Jan 1970 00:00:01 GMT;path=/s;";
      document.cookie = cookieString;
      document.cookie = cookieStrings;
    }
  }

  setStartingCookiePreferences(cookieData) {
    for (let i = 0, len = cookieData.length; i < len; i++) {
      this.cookiePreferences.push({ authorizationFormId: cookieData[i].RelatedAuthorizationFormId, value: cookieData[i].DefaultValue });
    }
  }

  verifyBrowserId() {
    verifyBrowserId({ browserId: this.browserId })
      .then(data => {
        if (data === false) {
          this.getCookieSectionsAndData();
        } else if (this.displayType === "page") {
          this.getCookieSectionsAndData();
        } else if (data === true) {
          this.getCookiesAndDropThem();
        }

        this.showCookieDialog = !data;
      })
      .catch(error => {});
  }

  acceptCookies() {
    createCookieConsentRecords({ browserId: this.browserId, cookiePreferences: this.cookiePreferences })
      .then(data => {
        this.showCookieDialog = false;
      })
      .catch(error => {});
  }

  rejectCookies() {
    window.history.back();
  }

  get shouldIShowCookieDialog() {
    if (this.showCookieDialog === true) {
      return true;
    }

    return false;
  }

  updateSectionStatus(event) {
    let authorizationFormId = event.target.name;
    let value = event.target.checked;

    let updatedPreference = { authorizationFormId: authorizationFormId, value: value };

    const newArray = [].concat(this.cookiePreferences, updatedPreference);

    this.cookiePreferences = newArray;
    this.dedupeCookiePreferences(this.cookiePreferences);
  }

  dedupeCookiePreferences(cookiePreferences) {
    let obj = {};

    for (let i = 0, len = cookiePreferences.length; i < len; i++) {
      obj[cookiePreferences[i]["authorizationFormId"]] = cookiePreferences[i];
    }

    cookiePreferences = new Array();

    for (let key in obj) {
      cookiePreferences.push(obj[key]);
    }

    this.cookiePreferences = cookiePreferences;
  }

  showSection(event) {
    let arrayCopy = JSON.parse(JSON.stringify(this.cookieData));

    let sectionName = event.currentTarget.dataset.value;

    for (let key in arrayCopy) {
      if (arrayCopy[key].SectionName === sectionName) {
        try {
          arrayCopy[key].ShowSection = !arrayCopy[key].ShowSection;

          if (arrayCopy[key].ShowSection === true) {
            arrayCopy[key].SectionIcon = "utility:chevrondown";
          } else {
            arrayCopy[key].SectionIcon = "utility:chevronright";
          }
        } catch (error) {}
      }
    }

    this.cookieData = arrayCopy;
  }

  informationButtonSelected() {
    let url = this.informationButtonLink;

    window.open(url, "_blank");
  }

  cookiesButtonSelected() {
    let url = this.viewCookiesLink;

    window.open(url);
  }

  get headingStyle() {
    return "font-size:1.2rem;font-weight:bold;color:" + this.cookieFooterTextColor;
  }

  get textStyle() {
    return "font-size:.9rem;color:" + this.cookieFooterTextColor;
  }

  get linkStyle() {
    return "font-size:.9rem;font-weight:bold;color:" + this.cookieFooterLinkColor;
  }

  get backgroundStyle() {
    return "background-color:" + this.cookieFooterBackgroundColor;
  }

  get footerState() {
    if (this.displayType === "footer" && this.showCookieDialog === true) {
      return true;
    } else {
      return false;
    }
  }

  get modalState() {
    return this.displayType === "modal";
  }

  get pageState() {
    return this.displayType === "page";
  }
}
