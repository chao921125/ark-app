import { CommonConstants } from '../common/constants/CommonConstants';
import MinePageContentComponent from '../view/MinePageContentComponent';

/**
 * Personal Center page, displaying personal information and app-related settings.
 */
@Entry
@Component
struct MinePage {
  @Builder NavigationTitle() {
    Row() {
      Text($r('app.string.mine_page_title'))
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

      Image($r("app.media.ic_user_profile"))
        .width($r('app.float.user_profile_image_width'))
        .height($r('app.float.user_profile_image_height'))
        .objectFit(ImageFit.Contain)
        .margin({ top: $r('app.float.profile_image_margin_top') })

      Text($r('app.string.user_nickname'))
        .textAlign(TextAlign.Center)
        .fontWeight(CommonConstants.NICKNAME_FONT_WEIGHT)
        .fontSize($r('app.float.nickname_font_size'))
        .margin({ top: $r('app.float.nickname_margin_top') })

      MinePageContentComponent()
    }
    .width(CommonConstants.MINE_PAGE_WIDTH_PERCENT)
    .height(CommonConstants.MINE_PAGE_HEIGHT_PERCENT)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.login_page_background'))
  }
}