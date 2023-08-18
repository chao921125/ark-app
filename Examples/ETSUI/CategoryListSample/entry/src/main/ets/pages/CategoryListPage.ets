import { CommonConstants } from '../common/constants/CommonConstants';
import { Category } from '../common/bean/Category';
import { CategoryComponent } from '../view/CategoryComponent';
import PageViewModel from '../viewmodel/PageViewModel';

/**
 * The CategoryListPage is the entry of application and shows how to develop a basic category list.
 * The page contains Navigation, Search and CategoryComponent which consists of several categories. The items in the
 * category are incremented, from one to six.
 * Developers can modify or add own text and images, and quickly develop functions that meet project requirements.
 */
@Entry
@Component
struct CategoryListPage {
  @Builder NavigationTitle() {
    Column() {
      Text($r('app.string.page_title'))
        .width(CommonConstants.NAVIGATION_TEXT_WIDTH_PERCENT)
        .fontColor($r('app.color.page_title'))
        .fontSize($r('app.float.navigation_title_size'))
    }
  }

  build() {
    Column() {
      Navigation()
        .hideBackButton(true)
        .title(this.NavigationTitle())
        .margin({
          top: $r('app.float.navigation_margin_top'),
          left: $r('app.float.navigation_margin_left'),
          right: $r('app.float.navigation_margin_right'),
          bottom: $r('app.float.navigation_margin_bottom')
        })
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
        .height($r('app.float.navigation_title_height'))

      Search({
        placeholder: CommonConstants.SEARCH_PLACEHOLDER
      })
        .height($r('app.float.search_height'))
        .border({ radius: $r('app.float.search_radius') })
        .backgroundColor($r('app.color.search_bar_background'))
        .placeholderColor($r('app.color.search_placeholder'))
        .placeholderFont({
          size: $r('app.float.search_text_size'),
          weight: CommonConstants.SEARCH_WEIGHT,
          family: CommonConstants.SEARCH_FONT_FAMILY,
          style: FontStyle.Normal
        })
        .textFont({ size: $r('app.float.search_text_size') })
        .margin({
          top: $r('app.float.search_margin_top'),
          bottom: $r('app.float.search_margin_bottom'),
          left: $r('app.float.search_margin_left'),
          right: $r('app.float.search_margin_right')
        })

      Scroll() {
        Column() {
          ForEach(PageViewModel.getCategoryData(), (category: Category) => {
            Text(category.title)
              .fontSize($r('app.float.sub_title_size'))
              .fontColor($r('app.color.list_item_summary'))
              .height($r('app.float.sub_title_height'))
              .margin({ left: $r('app.float.sub_title_margin_left') })
              .align(Alignment.BottomStart)
              .padding({ bottom: $r('app.float.text_padding_bottom') })

            CategoryComponent({ listData: category.categoryContent })
          }, category => JSON.stringify(category))
        }
		.alignItems(HorizontalAlign.Start)
      }
      .edgeEffect(EdgeEffect.Spring)
      .margin({
        top: $r('app.float.scroll_bottom_margin_top'),
        left: $r('app.float.scroll_margin_left'),
        right: $r('app.float.scroll_margin_right')
      })
      .layoutWeight(CommonConstants.SCROLL_WEIGHT)
    }
    .backgroundColor($r('app.color.theme_background'))
  }
}