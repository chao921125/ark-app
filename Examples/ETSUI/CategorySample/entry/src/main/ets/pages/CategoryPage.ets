import { CategoryListComponent } from '../view/CategoryListComponent';
import { CommonConstants } from '../common/constants/CommonConstants';
import { TabItem } from '../common/bean/TabItem';
import CategoryViewModel from '../viewmodel/CategoryViewModel';

/**
 * This module template implements Category functions.
 * The left and right sides of the page are linked. Click the left option and
 * the right list will slide to the specified position, and vice versa.
 * Developers can add corresponding data as needed after creating a template.
 */
@Entry
@Component
struct CategoryPage {
  @State categoryTabIndex: number = 1;

  build() {
    Column() {
      Navigation()
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
        .height($r('app.float.navigation_height'))
        .title(this.NavigationTitle())
        .hideBackButton(true)
        .margin({
          top: $r('app.float.navigation_margin_top')
        })

      Search({ placeholder: CommonConstants.SEARCH_PLACEHOLDER })
        .height($r('app.float.search_height'))
        .border({ radius: $r('app.float.search_radius') })
        .backgroundColor($r('app.color.search_bar_background'))
        .placeholderFont({
          size: $r('app.float.search_text_size'),
          weight: CommonConstants.SEARCH_WEIGHT,
          family: CommonConstants.SEARCH_FONT_FAMILY,
          style: FontStyle.Normal
        })
        .textFont({ size: $r('app.float.search_text_size') })
        .placeholderColor($r('app.color.search_placeholder'))
        .margin({
          top: $r('app.float.search_margin_top'),
          bottom: $r('app.float.search_margin_bottom'),
          left: $r('app.float.search_margin_left'),
          right: $r('app.float.search_margin_right')
        })

      Tabs({ index: this.categoryTabIndex, barPosition: BarPosition.End }) {
        ForEach(CategoryViewModel.getTabItems(), (item: TabItem, index: number) => {
          TabContent() {
            CategoryListComponent()
          }
          .tabBar(this.TabBottom(item, index))
        }, item => JSON.stringify(item))
      }
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.categoryTabIndex = index;
      })
      .layoutWeight(CommonConstants.TAB_LAYOUT_WEIGHT)
    }
    .backgroundColor($r('app.color.category_background'))
  }

  @Builder TabBottom(item: TabItem, index: number) {
    Column(){
      Image(this.categoryTabIndex === index ? item.imageActivated : item.imageOriginal)
        .height($r('app.float.tab_image_size'))
        .width($r('app.float.tab_image_size'))
        .margin({
          top: $r('app.float.tab_margin_top'),
          bottom: $r('app.float.tab_margin_bottom')
        })

      Text(item.title)
        .width($r('app.float.tab_text_width'))
        .height($r('app.float.tab_text_height'))
        .fontSize($r('app.float.tab_text_font_size'))
        .fontWeight(CommonConstants.TAB_ITEM_FONT_WEIGHT)
        .fontColor(this.categoryTabIndex === index
          ? $r('app.color.tab_text_activated')
          : $r('app.color.tab_text_normal'))
        .textAlign(TextAlign.Center)
        .margin({
          bottom: $r('app.float.tab_text_margin_bottom')
        })
    }
    .justifyContent(FlexAlign.Center)
    .width(CommonConstants.TAB_BAR_WIDTH_PERCENT)
    .height($r('app.float.tab_bar_height'))
  }

  @Builder NavigationTitle() {
    Column() {
      Text($r('app.string.navigation_title'))
        .width(CommonConstants.TEXT_WIDTH_PERCENT)
        .height($r('app.float.navigation_title_height'))
        .fontSize($r('app.float.navigation_title_font_size'))
        .fontWeight(CommonConstants.TITLE_FONT_WEIGHT)
        .textAlign(TextAlign.Start)

      Text($r('app.string.navigation_sub_title'))
        .width(CommonConstants.TEXT_WIDTH_PERCENT)
        .height($r('app.float.navigation_subtitle_height'))
        .fontColor($r('app.color.sub_text'))
        .fontSize($r('app.float.navigation_subtitle_font_size'))
        .fontWeight(CommonConstants.SUBTITLE_FONT_WEIGHT)
        .textAlign(TextAlign.Start)
    }
    .alignItems(HorizontalAlign.Start)
  }
}