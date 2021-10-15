/**
 * Due to locker service restrictions, we can not access a documents cookies within a component. We can include this script in our
 * communities head to serve as a broker for getting cookies from the dom. we cna fire the 'componentConnected' custom event and
 * capture it in this script. We can then get the cookies from the document and create the documentCookies custom event and fire it.
 * This event can be captured by the component for processing.
 */

window.addEventListener("componentConnected", function(e) {
  let fingerprint = getFingerprint();
  console.log('fingerprint ' + fingerprint);
  let event = new CustomEvent("documentCookies", { detail: fingerprint});
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

function getFingerprint(){
  const client = new ClientJS();
  const fingerprint = client.getFingerprint();
  return fingerprint;
}
