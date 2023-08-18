/*
 * Copyright (c) 2021 Huawei Device Co., Ltd.
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

import Curves from '@ohos.curves'
import router from '@system.router'
import { FoodData, Category } from '../model/FoodData'

@Component
struct PageTitle {
  build() {
    Flex({ alignItems: ItemAlign.Start }) {
      Image($r('app.media.Back'))
        .width(21.8)
        .height(19.6)
      Text('Food Detail')
        .fontSize(21.8)
        .margin({ left: 17.4 })
    }
    .height(61)
    .backgroundColor('#FFedf2f5')
    .padding({ top: 13, bottom: 15, left: 28.3 })
    .onClick(() => {
      router.back()
    })
  }
}

@Component
struct FoodImageDisplay {
  private foodItem: FoodData
  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image(this.foodItem.image)
        .objectFit(ImageFit.Contain)
        .sharedTransition(this.foodItem.id, { duration: 1000, curve: Curves.cubicBezier(0.2, 0.2, 0.1, 1.0), delay: 100})
      Text(this.foodItem.name)
        .fontSize(26)
        .fontWeight(500)
        .margin({ left: 26, bottom: 17.4 })
    }
    .backgroundColor('#FFedf2f5')
    .height(357)
  }
}

@Component
struct ContentTable {
  private foodItem: FoodData
  @Builder IngredientItem(title:string, colorValue: string, name: string, value: string) {
    Flex() {
      Text(title)
        .fontSize(17.4)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Flex({ alignItems: ItemAlign.Center }) {
        Circle({ width: 6, height: 6 })
          .margin({ right: 12 })
          .fill(colorValue)
        Text(name)
          .fontSize(17.4)
          .flexGrow(1)
        Text(value)
          .fontSize(17.4)
      }
      .layoutWeight(2)
    }
  }

  build() {
    Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.SpaceBetween, alignItems: ItemAlign.Start }) {
      this.IngredientItem('Calories', '#FFf54040', 'Calories', this.foodItem.calories + 'kcal')
      this.IngredientItem('Nutrition', '#FFcccccc', 'Protein', this.foodItem.protein + 'g')
      this.IngredientItem(' ', '#FFf5d640', 'Fat', this.foodItem.fat + 'g')
      this.IngredientItem(' ', '#FF9e9eff', 'Carbohydrates', this.foodItem.carbohydrates + 'g')
      this.IngredientItem(' ', '#FF53f540', 'VitaminC', this.foodItem.vitaminC + 'mg')
    }
    .padding({ top: 20, right: 20, left: 20 })
    .height(250)
  }
}

@Entry
@Component
struct FoodDetail {
  private foodItem: FoodData = router.getParams().foodId
  build() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        FoodImageDisplay({ foodItem: this.foodItem })
        PageTitle()
      }
      ContentTable({ foodItem: this.foodItem })
    }
    .alignItems(HorizontalAlign.Center)
  }
}