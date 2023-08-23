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
export struct SourceImageComponent {
  @Link sliderValue: number;

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($r("app.media.ic_source_image"))
        .width(CommonConstants.FULL_WIDTH)
        .height(CommonConstants.FULL_HEIGHT)
        .objectFit(ImageFit.Fill)

      Image($r('app.media.ic_transverse_line'))
        .width(CommonConstants.FULL_WIDTH)
        .height(CommonConstants.TRANSVERSE_LINE_HEIGHT)
        .objectFit(ImageFit.Fill)
        .margin({ top: StringUtil.numberToPercentage(this.sliderValue) })

      Image($r('app.media.ic_transverse_line'))
        .width(CommonConstants.FULL_WIDTH)
        .height(CommonConstants.TRANSVERSE_LINE_HEIGHT)
        .objectFit(ImageFit.Fill)
        .margin({ top: StringUtil.numberToPercentage(CommonConstants.IMAGE_MAX_WIDTH_PERCENTAGE
        - this.sliderValue) })

      Image($r('app.media.ic_vertical_line'))
        .width(CommonConstants.VERTICAL_LINE_HEIGHT)
        .height(CommonConstants.FULL_HEIGHT)
        .objectFit(ImageFit.Fill)
        .margin({ left: StringUtil.numberToPercentage(this.sliderValue) })

      Image($r('app.media.ic_vertical_line'))
        .width(CommonConstants.VERTICAL_LINE_HEIGHT)
        .height(CommonConstants.FULL_HEIGHT)
        .objectFit(ImageFit.Fill)
        .margin({
          left: StringUtil.numberToPercentage(CommonConstants.IMAGE_MAX_WIDTH_PERCENTAGE
          - this.sliderValue)
        })
    }
    .width(CommonConstants.STACK_WIDTH)
    .height(CommonConstants.STACK_HEIGHT)
    .margin({
      left: CommonConstants.STACK_MARGIN_LEFT,
      top: $r('app.float.stack_margin_top')
    })
  }
}