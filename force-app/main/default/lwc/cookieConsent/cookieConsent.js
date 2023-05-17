import { LightningElement, track, api } from "lwc";
import getCookieData from "@salesforce/apex/CookieConsentService.getCookieData";
import createCookieConsentRecords from "@salesforce/apex/CookieConsentServiceGuestHelper.createCookieConsentRecords";
import verifyBrowserId from "@salesforce/apex/CookieConsentService.verifyBrowserId";
import getCookiesToDelete from "@salesforce/apex/CookieConsentServiceGuestHelper.getCookiesToDelete";

export default class CookieConsent extends LightningElement {
  // State
  @api displayType = "footer";
  @api useRelaxedCSP = false;
  showCookieDialog;
  preview;
  loading = true;
  finterprintInitialized = false;
  showConnectionError;

  // Data
  cookiePreferences = [];
  @track cookieData;
  uniqueId;
  client;
  callCount = 0;

  // Design
  @api headingLabel = "Manage Cookies";
  @api instructions = "Cookie Instructions";
  @api informationButtonLabel = "View Privacy Policy";
  @api informationButtonLink = "https://www.salesforce.com";
  @api viewCookiesLabel = "View Cookies";
  @api viewCookiesLink = "https://www.salesforce.com";
  @api confirmButtonLabel = "Confirm Preferences";
  @api rejectButtonLabel = "Leave Site";
  @api cookieFooterRelative = false;
  @api cookieFooterPadding = "small";
  @api cookieFooterButtonAlignment = "center";
  @api cookieFooterBackgroundColor = "rgb(0,0,0)";
  @api cookieFooterLinkColor = "rgb(250, 250, 250)";
  @api cookieFooterTextColor = "rgb(250, 250, 250)";
  @api previewInBuilder = false;
  error;

  connectedCallback() {
    this.checkIfInPreview();
    if (this.useRelaxedCSP && !this.preview) {
      this.getBrowserIdCookie();
    } else if (!this.useRelaxedCSP && !this.preview) {
      try {
        window.addEventListener("documentCookies", this.receiveCookiesFromHead.bind(this), false);
      } catch (e) {
        console.log("error: " + e);
      }
      this.getCookiesFromHead();
    } else if (this.previewInBuilder) {
      this.uniqueId = Math.random();
      this.verifyBrowserIdWithUniqueId();
    }
  }

  checkIfInPreview() {
    let urlToCheck = window.location.href;
    if (!urlToCheck) {
      urlToCheck = window.location.hostname;
    }
    if (!urlToCheck) {
      this.preview = false;
    } else {
      urlToCheck = urlToCheck.toLowerCase();
      this.preview = urlToCheck.indexOf("sitepreview") >= 0 || urlToCheck.indexOf("livepreview") >= 0;  
    }

  }

  getCookiesFromHead() {
    this.callCount++;
    let event = new CustomEvent("componentConnected");
    window.dispatchEvent(event);
  }

  @api
  receiveCookiesFromHead(e) {
    this.uniqueId = e.detail;
    if (this.uniqueId) {
      this.verifyBrowserIdWithUniqueId();
    } else if(this.callCount <= 5) {
      this.getCookiesFromHead();
    } else {
      this.showConnectionError = true;
    }
  }


  @api
  verifyBrowserIdWithUniqueId() {
    verifyBrowserId({ browserId: this.uniqueId })
      .then(data => {
        if (data === false) {
          this.getCookieSectionsAndData();
        } else if (this.displayType === "page") {
          this.getCookieSectionsAndData();
        } else if (data === true) {
          this.getCookiesAndDeleteThem();
        }
        this.showCookieDialog = !data;
      })
      .catch(error => {
        this.error = error.message;
      });
  }

  @api
  getCookieSectionsAndData() {
    getCookieData()
      .then(data => {
        this.cookieData = [...data];
        console.log('cookies', JSON.stringify(this.cookieData));
        this.setStartingCookiePreferences(data);
        this.loading = false;
      })
      .catch(error => {});
  }

  @api
  setStartingCookiePreferences(cookieData) {
    for (let i = 0, len = cookieData.length; i < len; i++) {
      this.cookiePreferences.push({ authorizationFormId: cookieData[i].RelatedAuthorizationFormId, value: cookieData[i].DefaultValue });
    }
  }

  getCookiesAndDeleteThem() {
    getCookiesToDelete({ browserId: this.uniqueId })
      .then(data => {
        if (this.useRelaxedCSP) {
          this.deleteCookiesOutsideLocker(data);
        } else {
          this.deleteCookiesInsideLocker(data);
        }
      })
      .catch(error => {
        this.error = error.message;
      });
  }

  deleteCookiesOutsideLocker(cookies) {
    for (let i = 0, len = cookies.length; i < len; i++) {
      let cookieWithStandardPath = cookies[i] + "=; expires=Thu, 01 Jan 1970 00:00:01 GMT;path=/;";
      let cookieWithCommunityPath = cookies[i] + "=; expires=Thu, 01 Jan 1970 00:00:01 GMT;path=/s;";
      document.cookie = cookieWithStandardPath;
      document.cookie = cookieWithCommunityPath;
    }
  }

  deleteCookiesInsideLocker(cookies) {
    let event = new CustomEvent("deleteCookies", { detail: cookies });
    window.dispatchEvent(event);
  }

  acceptCookies() {
    createCookieConsentRecords({ browserId: this.uniqueId, cookiePreferences: this.cookiePreferences })
      .then(data => {
        this.showCookieDialog = false;
      })
      .catch(error => {
        this.error = error.message;
      });
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
        } catch (error) {
          this.error = error.message;
        }
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
    return this.displayType === "footer" && this.showCookieDialog === true;
  }

  get modalState() {
    return this.displayType === "modal";
  }

  get pageState() {
    return this.displayType === "page";
  }

  get footerButtonClass() {
    switch (this.cookieFooterButtonAlignment) {
      case "left":
        return "slds-grid slds-wrap";
      case "center":
        return "slds-grid slds-wrap slds-grid--align-center";
      case "right":
        return "slds-grid slds-wrap slds-grid--align-end";
      default:
        return "slds-grid slds-wrap";
    }
  }

  get footerContainerPadding() {
    return "slds-size--1-of-1 slds-p-around_" + this.cookieFooterPadding;
  }

  get footerContainerClass() {
    if (this.cookieFooterRelative === false) {
      return "cookiecon-footer-container-fixed";
    } else {
      return "cookiecon-footer-container-relative";
    }
  }
}