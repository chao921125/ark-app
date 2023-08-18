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

import { SourceImageComponent } from '../view/SourceImageComponent';
import { CommonConstants } from '../common/constants/CommonConstants';

@Component
export struct SliceAdjustComponent {
  @Link sliderValue: number;

  build() {
    Column() {
      Text($r('app.string.source_image'))
        .width(CommonConstants.TEXT_WIDTH)
        .height($r('app.float.text_height'))
        .fontSize($r('app.float.font_size'))
        .fontWeight(CommonConstants.TITLE_WEIGHT)
        .fontColor($r('app.color.text_font'))
        .margin({
          left: CommonConstants.TEXT_MARGIN_LEFT,
          bottom: CommonConstants.TEXT_MARGIN_BOTTOM
        })
      Column() {
        SourceImageComponent({ sliderValue: $sliderValue })

        Slider({
          value: this.sliderValue,
          min: CommonConstants.SLICE_SLIDER_MIN,
          max: CommonConstants.SLICE_SLIDER_MAX,
          step: CommonConstants.SLIDER_STEP,
          style: SliderStyle.InSet
        })
          .width(CommonConstants.SLIDER_WIDTH)
          .margin({
            left: CommonConstants.SLIDER_MARGIN_LEFT,
            top: $r('app.float.slider_margin_top')
          })
          .onChange((value: number) => {
            this.sliderValue = value;
          })

        Text($r('app.string.hint_text'))
          .margin({ left: CommonConstants.SOURCE_TEXT_MARGIN_LEFT })
          .fontSize($r('app.float.text_size'))
          .fontColor($r('app.color.text_background'))
      }
      .width(CommonConstants.COLUMN_WIDTH)
      .height(CommonConstants.COLUMN_HEIGHT)
      .alignItems(HorizontalAlign.Start)
      .borderRadius($r('app.float.border_radius'))
      .margin({ left: CommonConstants.COLUMN_MARGIN_LEFT })
      .backgroundColor(Color.White)
    }
    .width(CommonConstants.FULL_WIDTH)
    .height($r('app.float.column_height'))
    .alignItems(HorizontalAlign.Start)
    .margin({
      top: $r('app.float.column_margin_top')
    })
  }
}