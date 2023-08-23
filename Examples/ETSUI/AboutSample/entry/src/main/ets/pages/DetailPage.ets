import router from '@ohos.router';
import { DetailListComponent } from '../view/DetailListComponent';
import { CommonConstants } from '../common/constants/CommonConstants';
import { ListItemData } from '../common/bean/ListItemData';
import AboutViewModel from '../viewmodel/AboutViewModel';

/**
 * Detail page. Click the item on about page to jump to the detail page.
 */
@Entry
@Component
struct DetailPage {
  private titleParam: Resource = $r('app.string.detail_default_title');
  private dataParam: Array<ListItemData> = AboutViewModel.getDefaultDetailInfo();

  aboutToAppear() {
    if (router.getParams()) {
      this.titleParam = router.getParams()[CommonConstants.KEY_PARAM_TITLE];
      this.dataParam = router.getParams()[CommonConstants.KEY_PARAM_DATA];
    }
  }

  @Builder NavigationTitle() {
    Column() {
      Text(this.titleParam)
        .width(CommonConstants.NAVIGATION_TITLE_WIDTH_PERCENT)
        .fontColor($r('app.color.title'))
        .fontSize($r('app.float.title_text_font_size'))
    }
  }

  build() {
    Column() {
      Navigation()
        .title(this.NavigationTitle())
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
        .height($r('app.float.title_height'))

      DetailListComponent({ detailList: this.dataParam })
    }
    .width(CommonConstants.DETAIL_COLUMN_WIDTH_PERCENT)
    .height(CommonConstants.DETAIL_COLUMN_HEIGHT_PERCENT)
    .backgroundColor($r('app.color.detail_background'))
  }
}