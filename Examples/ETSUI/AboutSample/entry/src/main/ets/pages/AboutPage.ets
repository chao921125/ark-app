import { TechSupportComponent } from '../view/TechSupportComponent';
import { AppInfoComponent } from '../view/AppInfoComponent';
import { LogoAndVersionComponent } from '../view/LogoAndVersionComponent';
import { CommonConstants } from '../common/constants/CommonConstants';
import AboutViewModel from '../viewmodel/AboutViewModel';

/**
 * This template implements the about function and contains three components.
 * The top is the LogoAndVersion component, the middle shows the relevant information of the application, and the
 * bottom is the privacy agreement and copyright statement.
 * Developers can enrich the application information and improve the relevant link information.
 */
@Entry
@Component
struct AboutPage {
  build() {
    Column() {
      Navigation()
        .title(this.NavigationTitle())
        .hideToolBar(true)
        .height($r('app.float.title_height'))
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)

      Scroll() {
        Column() {
          LogoAndVersionComponent()

          AppInfoComponent({
            appInfoData: AboutViewModel.getAppInfo()
          })

          Blank()

          TechSupportComponent()
        }
        .height(CommonConstants.SCROLL_HEIGHT_PERCENT)
        .constraintSize({ minHeight: $r('app.float.scroll_min_height') })
      }
      .layoutWeight(CommonConstants.SCROLL_WEIGHT)
    }
  }

  @Builder NavigationTitle() {
    Text($r('app.string.title_name'))
      .fontSize($r('app.float.title_text_font_size'))
      .fontColor($r('app.color.title'))
      .fontWeight(CommonConstants.FONT_WEIGHT)
  }
}