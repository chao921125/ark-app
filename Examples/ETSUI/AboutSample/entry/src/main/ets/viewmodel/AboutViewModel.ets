import { ListItemData } from '../common/bean/ListItemData';
import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * About ability view model.
 */
class AboutViewModel {
  /**
   * Get application information.
   *
   * @return {Array<ListItemData>} appInfo
   */
  getAppInfo() {
    let appInfo: Array<ListItemData> = [];
    let aboutUsData: ListItemData = new ListItemData();
    aboutUsData.id = CommonConstants.ABOUT_US_ID;
    aboutUsData.title = $r('app.string.about_us');
    aboutUsData.icon = $r("app.media.ic_arrow");
    appInfo.push(aboutUsData);
    let contactData: ListItemData = new ListItemData();
    contactData.id = CommonConstants.CONTACT_ID;
    contactData.title = $r('app.string.contact_customer_service');
    contactData.icon = $r("app.media.ic_arrow");
    appInfo.push(contactData);
    return appInfo;
  }

  /**
   * Get about us information.
   *
   * @return {Array<ListItemData>} aboutUsInfo
   */
  getAboutUsInfo() {
    let aboutUsInfo: Array<ListItemData> = [];
    let officialWeb: ListItemData = new ListItemData();
    officialWeb.title = $r('app.string.home_page');
    officialWeb.summary = $r("app.string.home_weblink");
    aboutUsInfo.push(officialWeb);
    let publicAccount: ListItemData = new ListItemData();
    publicAccount.title = $r('app.string.public_account');
    publicAccount.summary = $r("app.string.account_name");
    aboutUsInfo.push(publicAccount);
    return aboutUsInfo;
  }

  /**
   * Get contact information.
   *
   * @return {Array<ListItemData>} contactInfo
   */
  getContactInfo() {
    let contactInfo: Array<ListItemData> = [];
    let serviceHotline: ListItemData = new ListItemData();
    serviceHotline.title = $r('app.string.service_hotline');
    serviceHotline.summary = $r("app.string.hotline_number");
    contactInfo.push(serviceHotline);
    let emailAddress: ListItemData = new ListItemData();
    emailAddress.title = $r('app.string.email');
    emailAddress.summary = $r("app.string.email_address");
    contactInfo.push(emailAddress);
    return contactInfo;
  }

  /**
   * Get detail page default information.
   *
   * @return {Array<ListItemData>} contactInfo
   */
  getDefaultDetailInfo(){
    let defaultInfo: Array<ListItemData> = [];
    for(let i = 0; i < CommonConstants.DETAIL_DEFAULT_ROW; i++){
      let defaultData: ListItemData = new ListItemData();
      defaultData.title = $r('app.string.detail_item_title');
      defaultData.summary = $r("app.string.arrow_title");
      defaultInfo.push(defaultData);
    }
    return defaultInfo;
  }
}

let aboutViewModel = new AboutViewModel();

export default aboutViewModel as AboutViewModel;