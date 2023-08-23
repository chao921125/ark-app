import router from '@ohos.router';
import { CommonConstants } from '../common/constants/CommonConstants';
import { DetailListComponent } from '../view/DetailListComponent';

/**
 * Detail page to display more information.
 */
@Entry
@Component
struct DetailPage {
  private titleParam: Resource = $r('app.string.detail_default_title');

  aboutToAppear() {
    if (router.getParams()) {
      this.titleParam = router.getParams()[CommonConstants.KEY_PARAM_DATA];
    }
  }

  @Builder NavigationTitle() {
    Column() {
      Text(this.titleParam)
        .width(CommonConstants.NAVIGATION_TEXT_WIDTH_PERCENT)
        .fontColor($r('app.color.page_title'))
        .fontSize($r('app.float.detail_navigation_title_size'))
    }
  }

  build() {
    Column() {
      Navigation()
        .title(this.NavigationTitle())
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
        .height($r('app.float.navigation_height'))

      DetailListComponent()
    }
    .width(CommonConstants.DETAIL_COLUMN_WIDTH_PERCENT)
    .height(CommonConstants.DETAIL_COLUMN_HEIGHT_PERCENT)
    .backgroundColor($r('app.color.theme_background'))
  }
}