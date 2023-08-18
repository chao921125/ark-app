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

import { MyDataSource } from '../util/DataSource'

@Component
export default struct ThemeDesktop {
  @Link themeDatas: Array<{
    image: Resource,
    name: string
  }>
  @State default: any[] = [
    { image: $r('app.media.dialer'), name: '电话' },
    { image: $r('app.media.shopping'), name: '商城' },
    { image: $r('app.media.notes'), name: '备忘录' },
    { image: $r('app.media.settings'), name: '设置' },
    { image: $r('app.media.camera'), name: '相机' },
    { image: $r('app.media.gallery'), name: '相册' },
    { image: $r('app.media.music'), name: '音乐' },
    { image: $r('app.media.video'), name: '视频' },
  ]

  build() {
    Grid() {
      ForEach(this.themeDatas, (item) => {
        GridItem() {
          Column() {
            Image(item.image)
              .width(70)
              .height(70)
              .objectFit(ImageFit.Fill)
            Text(item.name).fontSize(15)
          }
          .width(90)
          .height(90)
        }
      })
    }
    .rowsGap(10)
    .width('100%')
    .columnsGap(10)
    .layoutWeight(1)
    .padding({ top: 20 })
    .backgroundColor('#e5e5e5')
    .columnsTemplate('1fr 1fr 1fr 1fr')
  }
}