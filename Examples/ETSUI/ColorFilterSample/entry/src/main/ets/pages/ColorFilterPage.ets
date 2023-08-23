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

import CommonConstants from '../common/constants/CommonConstants';

/**
 * The sample to show the developer how to use the colorFilter property to set color of the image.
 */
@Entry
@Component
struct ColorFilterPage {
  private colorFilterMatrix: number[] = [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0
  ];
  @State colorFilter: ColorFilter = new ColorFilter(this.colorFilterMatrix);

  @Builder NavigationTitle() {
    Text($r('app.string.title'))
      .fontSize($r('app.float.title_text_size'))
      .fontWeight(CommonConstants.TEXT_FONT_WEIGHT)
  }

  build() {
    Column() {
      Navigation()
        .title(this.NavigationTitle())
        .width(CommonConstants.FULL_WIDTH)
        .height($r('app.float.title_height'))

      Scroll() {
        Column() {
          Image($r('app.media.color_filter'))
            .width($r('app.float.image_width'))
            .height($r('app.float.image_height'))
            .margin({ top: $r('app.float.image_margin_top') })
            .objectFit(ImageFit.Contain)
            .colorFilter(this.colorFilter)

          Column() {
            Text($r('app.string.rgba_text'))
              .fontColor($r('app.color.text_color'))
              .fontSize($r('app.float.rgba_text_size'))
              .fontWeight(CommonConstants.TEXT_FONT_WEIGHT)
              .margin({
                left: $r('app.float.rgba_text_margin_left'),
                top: $r('app.float.rgba_text_margin_top')
              })

            Grid() {
              ForEach(this.colorFilterMatrix, (item: number, index: number) => {
                GridItem() {
                  TextInput({ text: item.toString() })
                    .type(InputType.Number)
                    .fontSize($r('app.float.input_text_size'))
                    .backgroundColor($r('app.color.input_background'))
                    .border({
                      width: $r('app.float.input_border_width'),
                      color: $r('app.color.input_border_color'),
                      radius: $r('app.float.input_border_radius')
                    })
                    .onChange((value: string) => {
                      if (value !== '') {
                        this.colorFilterMatrix[index] = parseInt(value);
                      }
                    })
                }
              }, item => JSON.stringify(item))
            }
            .columnsTemplate(CommonConstants.COLUMN_TEMPLATE)
            .rowsTemplate(CommonConstants.ROW_TEMPLATE)
            .columnsGap($r('app.float.grid_column_gap'))
            .rowsGap($r('app.float.grid_row_gap'))
            .height($r('app.float.grid_height'))
            .margin($r('app.float.grid_margin'))
          }
          .alignItems(HorizontalAlign.Start)
          .backgroundColor($r('app.color.column_grid_background'))
          .borderRadius($r('app.float.column_grid_radius'))
          .margin({
            left: $r('app.float.column_grid_margin_left'),
            right: $r('app.float.column_grid_margin_right'),
            top: $r('app.float.column_grid_margin_top')
          })

          Text($r('app.string.explain_text'))
            .fontSize($r('app.float.explain_text_size'))
            .fontColor($r('app.color.explain_text_color'))
            .align(Alignment.Start)
            .margin({
              left: $r('app.float.explain_text_margin_left'),
              right: $r('app.float.explain_text_margin_right'),
              top: $r('app.float.explain_text_margin_top')
            })

          Button($r('app.string.button_text'))
            .width(CommonConstants.BUTTON_WIDTH)
            .margin({
              top: $r('app.float.button_margin_top'),
              bottom: $r('app.float.button_margin_bottom')
            })
            .onClick(() => {
              this.colorFilter = new ColorFilter(this.colorFilterMatrix);
            })
        }
      }
      .scrollBar(BarState.Off)
      .layoutWeight(CommonConstants.SCROLL_LAYOUT_WEIGHT)
    }
    .height(CommonConstants.FULL_HEIGHT)
    .backgroundColor($r('app.color.page_background'))
  }
}