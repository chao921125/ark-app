import { CommonConstants } from '../common/constants/CommonConstants';
import { CustomerListComponent } from '../view/CustomerListComponent';

/**
 * Customer service page. Click the help button to jump to the CustomerServicePage.
 */
@Entry
@Component
struct CustomerServicePage {
  @Builder NavigationTitle() {
    Row() {
      Text($r('app.string.contact_customer_service'))
        .fontSize($r('app.float.title_text_size'))
        .fontColor($r('app.color.title'))
        .fontWeight(CommonConstants.TITLE_FONT_WEIGHT)
    }
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      Navigation()
        .title(this.NavigationTitle())
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
        .height($r('app.float.title_height'))
        .backgroundColor($r('app.color.detail_background'))

      CustomerListComponent()
    }
    .width(CommonConstants.CUSTOMER_COLUMN_WIDTH_PERCENT)
    .height(CommonConstants.CUSTOMER_COLUMN_HEIGHT_PERCENT)
    .backgroundColor($r('app.color.detail_background'))
  }
}
