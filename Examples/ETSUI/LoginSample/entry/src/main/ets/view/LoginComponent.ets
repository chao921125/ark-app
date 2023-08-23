import router from '@ohos.router';
import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * Login page component.
 */
@Component
export struct LoginComponent {
  @State userName: string = '';
  @State password: string = '';

  build() {
    Column() {
      TextInput({ placeholder: $r('app.string.username') })
        .width(CommonConstants.TEXT_INPUT_WIDTH_PERCENT)
        .height($r('app.float.text_input_height'))
        .placeholderColor($r('app.color.text_input_place_holder'))
        .placeholderFont({ size: $r('app.float.text_input_font_size') })
        .backgroundColor($r('app.color.login_input_text_background'))
        .fontSize($r('app.float.text_input_font_size'))
        .padding({ left: $r('app.float.username_padding_left') })
        .onChange((value: string) => {
          this.userName = value;
        })

      Divider()
        .width(CommonConstants.DIVIDER_WIDTH_PERCENT)
        .height($r('app.float.divider_height'))
        .color($r('app.color.divider'))
        .alignSelf(ItemAlign.Center)

      TextInput({ placeholder: $r('app.string.password') })
        .width(CommonConstants.TEXT_INPUT_WIDTH_PERCENT)
        .height($r('app.float.text_input_height'))
        .placeholderColor($r('app.color.text_input_place_holder'))
        .placeholderFont({ size: $r('app.float.text_input_font_size') })
        .fontSize($r('app.float.text_input_font_size'))
        .backgroundColor($r('app.color.login_input_text_background'))
        .type(InputType.Password)
        .padding({ left: $r('app.float.password_padding_left') })
        .onChange((value: string) => {
          this.password = value;
        })

      Divider()
        .width(CommonConstants.DIVIDER_WIDTH_PERCENT)
        .height($r('app.float.divider_height'))
        .color($r('app.color.divider'))
        .alignSelf(ItemAlign.Center)

      Button($r('app.string.login'))
        .width(CommonConstants.BUTTON_WIDTH_PERCENT)
        .height($r('app.float.login_btn_height'))
        .margin({ top: $r('app.float.login_btn_margin_top') })
        .borderRadius($r('app.float.login_btn_border_radius'))
        .fontSize($r('app.float.text_input_font_size'))
        .fontWeight(CommonConstants.LOGIN_TEXT_FONT_WEIGHT)
        .enabled(isLoginButtonClickable(this.userName, this.password))
        .fontColor(isLoginButtonClickable(this.userName, this.password)
          ? Color.White
          : $r('app.color.login_font_normal'))
        .backgroundColor(isLoginButtonClickable(this.userName, this.password)
          ? $r('app.color.login_btn_enabled')
          : $r('app.color.login_btn_normal'))
        .onClick(() => {
          router.push({
            url: CommonConstants.MINE_PAGE_URL
          });
        })

      Button($r('app.string.register'))
        .width(CommonConstants.BUTTON_WIDTH_PERCENT)
        .height($r('app.float.login_btn_height'))
        .fontSize($r('app.float.text_input_font_size'))
        .fontWeight(CommonConstants.BUTTON_FONT_WEIGHT)
        .borderRadius($r('app.float.register_btn_border_radius'))
        .margin({ top: $r('app.float.register_btn_margin_top') })
        .fontColor($r('app.color.register_font_clickable'))
        .backgroundColor($r('app.color.register_btn_clickable'))
        .onClick(() => {
          router.push({
            url: CommonConstants.REGISTRATION_SUCCESS_PAGE_URL
          });
        })
    }
    .padding($r('app.float.login_operation_area_padding'))
  }
}

/**
 * Calculate login button clickable by the input of username and password.
 *
 * @return {boolean} isLoginButtonClickable.
 */
function isLoginButtonClickable(userName: string, password: string): boolean {
  return userName !== '' && password !== '';
}

