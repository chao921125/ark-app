import router from '@ohos.router';
import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * Component of privacy statement and help.
 */
@Component
export struct PrivacyStatementComponent {
  build() {
    Flex({
      direction: FlexDirection.Row,
      justifyContent: FlexAlign.Center
    }) {
      Text($r('app.string.problem_encountered'))
        .fontSize($r('app.float.statement_text_size'))
        .fontColor($r('app.color.problem_encountered_font'))
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.push({
            url: CommonConstants.CUSTOMER_SERVICE_PAGE_URL
          });
        })

      Text($r('app.string.privacy_statement'))
        .fontSize($r('app.float.statement_text_size'))
        .fontColor($r('app.color.privacy_statement_font'))
        .textAlign(TextAlign.Center)
        .margin({ left: $r('app.float.statement_space') })
        .onClick(() => {
          router.push({
            url: CommonConstants.PRIVACY_PAGE_URL
          });
        })
    }
    .width(CommonConstants.FLEX_WIDTH_PERCENT)
    .margin({
      bottom: $r('app.float.statement_area_margin_bottom')
    })
  }
}