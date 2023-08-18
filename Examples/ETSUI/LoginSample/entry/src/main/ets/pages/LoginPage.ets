import { CommonConstants } from '../common/constants/CommonConstants';
import { PrivacyStatementComponent } from '../view/PrivacyStatementComponent';
import { LoginComponent } from '../view/LoginComponent';

/**
 * This template implements the Login function.
 * First register personal details. Log in after entering the username and password.
 * Click the button at the bottom to ask for help and check the privacy statement.
 * Developers can save username and password by Preference or Relational Database.
 */
@Entry
@Component
struct LoginPage {
  @Builder NavigationTitle() {
    Row() {
      Text($r('app.string.title'))
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
        .hideToolBar(true)
        .align(Alignment.Start)
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
        .height($r('app.float.navigation_height'))

      Scroll() {
        Column() {
          LoginComponent()

          Blank()

          PrivacyStatementComponent()
        }
        .height(CommonConstants.SCROLL_HEIGHT_PERCENT)
        .constraintSize({ minHeight: $r('app.float.scroll_min_height') })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(CommonConstants.LOGIN_SCROLL_LAYOUT_WEIGHT)
    }
    .width(CommonConstants.LOGIN_PAGE_WIDTH_PERCENT)
    .backgroundColor($r('app.color.login_page_background'))
  }
}