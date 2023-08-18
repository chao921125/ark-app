import router from '@ohos.router';
import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * Privacy agreement and copyright statement page.
 */
@Component
export struct TechSupportComponent {
  build() {
    Column() {
      Row() {
        Text($r('app.string.user_protocol'))
          .fontSize($r('app.float.bottom_font_size'))
          .fontColor($r('app.color.text_link'))
          .onClick(() => this.openAgreementPage())
        Text($r('app.string.and'))
          .fontSize($r('app.float.bottom_font_size'))
          .fontColor($r('app.color.text_opacity'))
        Text($r('app.string.privacy_statement'))
          .fontSize($r('app.float.bottom_font_size'))
          .fontColor($r('app.color.text_link'))
          .onClick(() => this.openPrivacyPage())
      }

      Text($r('app.string.copyright'))
        .fontSize($r('app.float.bottom_font_size'))
        .fontColor($r('app.color.text_opacity'))
      Text($r('app.string.tech_support'))
        .fontSize($r('app.float.bottom_font_size'))
        .fontColor($r('app.color.text_opacity'))
    }
    .alignItems(HorizontalAlign.Center)
    .align(Alignment.Bottom)
    .margin({
      bottom: $r('app.float.bottom_padding_bottom')
    })
  }

  openAgreementPage() {
    router.push({
      url: CommonConstants.AGREEMENT_PAGE
    });
  }

  openPrivacyPage() {
    router.push({
      url: CommonConstants.PRIVACY_PAGE
    });
  }
}