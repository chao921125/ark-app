import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * Logo and version component on top page.
 */
@Component
export struct LogoAndVersionComponent {
  build() {
    Column() {
      Image($r("app.media.ic_logo"))
        .height($r('app.float.image_height'))
        .width($r('app.float.image_width'))
        .borderRadius($r('app.float.icon_radius'))
      Text($r('app.string.icon_name'))
        .fontSize($r('app.float.name_text_size'))
        .fontColor($r('app.color.text'))
        .fontWeight(CommonConstants.FONT_WEIGHT)
        .padding({ top: $r('app.float.name_text_padding_top') })
      Text($r('app.string.version_label', CommonConstants.APP_VERSION))
        .fontSize($r('app.float.version_text_size'))
        .fontColor($r('app.color.text_opacity'))
    }
    .alignItems(HorizontalAlign.Center)
    .align(Alignment.Top)
    .padding({
      top: $r('app.float.logo_padding_top'),
      bottom: $r('app.float.logo_padding_bottom')
    })
  }
}