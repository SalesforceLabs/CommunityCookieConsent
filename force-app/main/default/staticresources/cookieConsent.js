/**
 * Due to locker service restrictions, we can not access a documents cookies within a component. We can include this script in our
 * communities head to serve as a broker for getting cookies from the dom. we cna fire the 'componentConnected' custom event and
 * capture it in this script. We can then get the cookies from the document and create the documentCookies custom event and fire it.
 * This event can be captured by the component for processing.
 */
window.addEventListener("componentConnected", function(e) {
  let cookies = document.cookie;
  let event = new CustomEvent("documentCookies", { detail: cookies });
  window.dispatchEvent(event);
});
