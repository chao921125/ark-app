/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { StringUtil } from '../common/util/StringUtil';
import { CommonConstants } from '../common/constants/CommonConstants';

@Component
export struct PreviewComponent {
  @State borderImageSiding: number = CommonConstants.BORDER_IMAGE_SIDING;
  @Link sliceValue: number;

  build() {
    Column() {
      Text($r('app.string.target_component'))
        .width(CommonConstants.TARGET_TEXT_WIDTH)
        .height($r('app.float.target_text_height'))
        .fontSize($r('app.float.target_text_font_size'))
        .fontWeight(CommonConstants.PREVIEW_TITLE_WEIGHT)
        .fontColor($r('app.color.target_text'))
        .margin({
          left: CommonConstants.TARGET_TEXT_MARGIN_LEFT,
          bottom: CommonConstants.TARGET_TEXT_MARGIN_BOTTOM
        })

      Column() {
        Image($r("app.media.ic_target_component"))
          .width(CommonConstants.TARGET_IMAGE_WIDTH)
          .height(CommonConstants.TARGET_IMAGE_HEIGHT)
          .objectFit(ImageFit.Fill)
          .margin({
            left: CommonConstants.TARGET_IMAGE_MARGIN_LEFT,
            top: CommonConstants.TARGET_IMAGE_MARGIN_TOP
          })
          .borderImage({
            source: $r("app.media.ic_source_image"),
            slice: {
              left: StringUtil.numberToPercentage(this.sliceValue),
              top: StringUtil.numberToPercentage(this.sliceValue),
              right: StringUtil.numberToPercentage(this.sliceValue),
              bottom: StringUtil.numberToPercentage(this.sliceValue)
            },
            width: {
              left: this.borderImageSiding.toFixed(CommonConstants.DECIMAL_DIGITS),
              top: this.borderImageSiding.toFixed(CommonConstants.DECIMAL_DIGITS),
              right: this.borderImageSiding.toFixed(CommonConstants.DECIMAL_DIGITS),
              bottom: this.borderImageSiding.toFixed(CommonConstants.DECIMAL_DIGITS)
            },
            repeat: RepeatMode.Stretch,
            fill: false,
            outset: {
              left: $r('app.float.outset'),
              top: $r('app.float.outset'),
              right: $r('app.float.outset'),
              bottom: $r('app.float.outset')
            }
          })

        Slider({
          value: this.borderImageSiding,
          min: CommonConstants.PREVIEW_SLIDER_MIN,
          max: CommonConstants.PREVIEW_SLIDER_MAX,
          step: CommonConstants.PREVIEW_SLIDER_STEP,
          style: SliderStyle.InSet
        })
          .width(CommonConstants.PREVIEW_SLIDER_WIDTH)
          .margin({
            left: CommonConstants.PREVIEW_SLIDER_MARGIN_LEFT,
            top: $r('app.float.preview_slider_margin_top')
          })
          .onChange((value: number) => {
            this.borderImageSiding = value;
          })

        Text($r('app.string.preview_hint_text'))
          .margin({ left: CommonConstants.PREVIEW_TEXT_HINT_MARGIN_LEFT })
          .fontSize($r('app.float.text_size'))
          .fontColor($r('app.color.text_background'))
      }
      .width(CommonConstants.PREVIEW_COLUMN_WIDTH)
      .height(CommonConstants.PREVIEW_COLUMN_HEIGHT)
      .alignItems(HorizontalAlign.Start)
      .borderRadius($r('app.float.preview_column_radius'))
      .margin({ left: $r('app.float.preview_column_margin_left') })
      .backgroundColor(Color.White)
    }
    .width(CommonConstants.FULL_WIDTH)
    .height($r('app.float.preview_height'))
    .alignItems(HorizontalAlign.Start)
  }
}