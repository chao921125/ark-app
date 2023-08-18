import router from '@ohos.router';
import { CommonConstants } from '../common/constants/CommonConstants';
import { DetailListComponent } from '../view/DetailListComponent';

/**
 * Detail page entry. Click on the businessCard page to route to the detail page.
 */
@Entry
@Component
struct DetailPage {
  private title: Resource = $r('app.string.detail_default_title');

  aboutToAppear() {
    if (router.getParams()) {
      this.title = router.getParams()[CommonConstants.ROUTER_PARAMS_TITLE];
    }
  }

  @Builder NavigationTitle() {
    Text(this.title)
      .fontSize($r('app.float.tab_title_size'))
      .fontColor($r('app.color.title'))
      .fontWeight(CommonConstants.TITLE_FONT_WEIGHT)
  }

  build() {
    Column() {
      Navigation()
        .title(this.NavigationTitle())
        .hideToolBar(true)
        .height($r('app.float.title_height'))
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)

      DetailListComponent()
    }
    .width(CommonConstants.DETAIL_PAGE_WIDTH_PERCENT)
    .height(CommonConstants.DETAIL_PAGE_HEIGHT_PERCENT)
    .backgroundColor($r('app.color.common_background'))
  }
}