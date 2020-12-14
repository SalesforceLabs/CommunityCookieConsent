/**
 * Due to locker service restrictions, we can not access a documents cookies within a component. We can include this script in our
 * communities head to serve as a broker for getting cookies from the dom. we cna fire the 'componentConnected' custom event and
 * capture it in this script. We can then get the cookies from the document and create the documentCookies custom event and fire it.
 * This event can be captured by the component for processing.
 */
if (window.XMLHttpRequest) {
  xmlhttp = new XMLHttpRequest();
  xmlhttp.open("POST", "/_/52609e00b7ee307e", false);
  xmlhttp.send(null);
}
window.addEventListener("componentConnected", function(e) {
  let cookies = document.cookie;
  let event = new CustomEvent("documentCookies", { detail: cookies });
  window.dispatchEvent(event);
});

window.addEventListener("deleteCookies", function(e) {
  let cookies = e.detail;
  for (let i = 0, len = cookies.length; i < len; i++) {
    let cookieWithStandardPath = cookies[i] + "=; expires=Thu, 01 Jan 1970 00:00:01 GMT;path=/;";
    let cookieWithCommunityPath = cookies[i] + "=; expires=Thu, 01 Jan 1970 00:00:01 GMT;path=/s;";
    document.cookie = cookieWithStandardPath;
    document.cookie = cookieWithCommunityPath;
  }
});
