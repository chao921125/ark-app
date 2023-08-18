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

import { SliceAdjustComponent } from '../view/SliceAdjustComponent';
import { PreviewComponent } from '../view/PreviewComponent';
import { CommonConstants } from '../common/constants/CommonConstants';

@Entry
@Component
struct BorderImageSample {
  @State sliderValue: number = CommonConstants.SLIDER_DEFAULT_VALUE;

  @Builder NavigationTitle() {
    Column() {
      Text($r('app.string.navigation_text'))
        .width(CommonConstants.FULL_WIDTH)
        .height($r('app.float.navigation_text_height'))
        .fontSize($r('app.float.navigation_font_size'))
        .fontColor($r('app.color.navigation_font'))
        .fontWeight(CommonConstants.NAVIGATION_TITLE_WEIGHT)
    }
  }

  build() {
    Column() {
      Navigation()
        .width(CommonConstants.FULL_WIDTH)
        .height($r('app.float.navigation_height'))
        .title(this.NavigationTitle())
      Scroll() {
        Column() {
          SliceAdjustComponent({ sliderValue: $sliderValue })
          PreviewComponent({ sliceValue: $sliderValue })
        }
      }
      .layoutWeight(CommonConstants.LAYOUT_WEIGHT)
    }
    .width(CommonConstants.FULL_WIDTH)
    .height(CommonConstants.FULL_HEIGHT)
    .backgroundColor($r('app.color.column_background'))
  }
}