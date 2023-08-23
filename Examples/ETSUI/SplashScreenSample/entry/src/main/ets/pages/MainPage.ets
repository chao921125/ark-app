import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * The MainPage that is routed as the SplashScreenPage.
 */
@Entry
@Component
struct MainPage {
  build() {
    Row() {
      Column() {
        Text($r('app.string.main_page_content'))
          .fontSize($r('app.float.hello_world_font_size'))
          .fontWeight(FontWeight.Bold)
      }
      .width(CommonConstants.MAIN_PAGE_COLUMN_WIDTH)
    }
    .height(CommonConstants.MAIN_PAGE_ROW_WIDTH)
  }
}