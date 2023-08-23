import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * User agreement page.
 */
@Entry
@Component
struct AgreementPage {
  webController: WebController = new WebController();

  build() {
    Column() {
      Navigation()
        .hideToolBar(true)
        .height($r('app.float.title_height'))
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
      Image($r("app.media.ic_user_agreement"))
        .width($r('app.float.icon_length'))
        .height($r('app.float.icon_length'))
        .objectFit(ImageFit.Contain)
        .margin({
          top: $r('app.float.icon_margin_top'),
          bottom: $r('app.float.icon_margin_bottom')
        })
      Web({
        src: $rawfile('agreement.html'),
        controller: this.webController
      })
    }
  }
}