import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * Privacy statement page.
 */
@Entry
@Component
struct PrivacyPage {
  webController: WebController = new WebController();

  build() {
    Column() {
      Navigation()
        .hideToolBar(true)
        .height($r('app.float.title_height'))
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
      Image($r('app.media.ic_public_privacy'))
        .width($r('app.float.icon_length'))
        .height($r('app.float.icon_length'))
        .objectFit(ImageFit.Contain)
        .margin({
          top: $r('app.float.icon_margin_top'),
          bottom: $r('app.float.icon_margin_bottom')
        })
      Web({
        src: $rawfile('privacy.html'),
        controller: this.webController
      })
    }
  }
}