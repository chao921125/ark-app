import { CommonConstants } from '../common/constants/CommonConstants';
import { TabItemData } from '../common/bean/TabItemData';
import { ListAreaComponent } from '../view/ListAreaComponent';
import PageViewModel from '../viewmodel/PageViewModel';

/**
 * ListPage is the entry of application and shows how to develop a list page.The page consists of the search component,
 * list, and tabs. The list component is ListAreaComponent, and each item in the list corresponds to ListItemComponent.
 * The LazyForEach interface is used to implement high performance. Developers can expand
 * ListItemData, TabItemData, and PageViewModel, modify or add your own text, pictures, etc.,
 * and quickly develop functions that meet project requirements.
 */
@Entry
@Component
struct ListPage {
  @State currentTabIndex: number = 0;

  @Builder BuildTabs(item: TabItemData, index: number) {
    Column() {
      Image(this.currentTabIndex === index ? item.imageActivated : item.imageOriginal)
        .width($r('app.float.image_star_width'))
        .height($r('app.float.image_star_height'))
      Text(item.title)
        .margin({ top: $r('app.float.tab_text_margin_top') })
        .fontSize($r('app.float.tab_text_size'))
        .fontColor(this.currentTabIndex === index ? $r('app.color.tab_text_activated') : $r('app.color.tab_text_normal'))
    }
    .justifyContent(FlexAlign.Center)
    .width(CommonConstants.TABS_WIDTH_PERCENT)
    .height($r('app.float.tab_bar_height'))
  }

  @Builder NavigationTitle() {
    Column() {
      Text($r('app.string.page_title'))
        .width(CommonConstants.NAVIGATION_TITLE_WIDTH_PERCENT)
        .fontColor($r('app.color.navigation_title'))
        .fontSize($r('app.float.title_size'))
    }
  }

  build() {
    Column() {
      Navigation()
        .backgroundColor($r('app.color.theme_background'))
        .hideBackButton(true)
        .title(this.NavigationTitle())
        .margin({
          top: $r('app.float.navigation_margin_top'),
          left: $r('app.float.navigation_margin_left'),
          right: $r('app.float.navigation_margin_right'),
          bottom: $r('app.float.navigation_margin_bottom')
        })
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
        .height($r('app.float.navigation_height'))
      Tabs({
        index: this.currentTabIndex,
        barPosition: BarPosition.End
      }) {
        ForEach(PageViewModel.getTabData(), (item: TabItemData, index) => {
          TabContent() {
            Column() {
              Search({
                placeholder: CommonConstants.SEARCH_PLACEHOLDER
              })
                .width(CommonConstants.SEARCH_WIDTH_PERCENT)
                .height($r('app.float.search_height'))
                .border({ radius: $r('app.float.search_radius') })
                .backgroundColor($r('app.color.search_bar_background'))
                .placeholderColor($r('app.color.search_placeholder'))
                .placeholderFont({
                  size: $r('app.float.search_text_size'),
                  weight: CommonConstants.SEARCH_FONT_WEIGHT,
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

              ListAreaComponent()
            }
            .justifyContent(FlexAlign.Center)
            .width(CommonConstants.SEARCH_WIDTH_PERCENT)
          }
          .backgroundColor($r('app.color.theme_background'))
          .tabBar(this.BuildTabs(item, index))
          .padding({
            left: $r('app.float.tab_content_padding_left'),
            right: $r('app.float.tab_content_padding_right')
          })
        }, item => JSON.stringify(item))
      }
      .margin({ top: $r('app.float.tab_margin_top') })
      .layoutWeight(CommonConstants.TAB_LAYOUT_WEIGHT)
      .backgroundColor($r('app.color.tab_bar_background'))
      .barHeight($r('app.float.tab_bar_height'))
      .onChange(index => {
        this.currentTabIndex = index;
      })
    }
    .backgroundColor($r('app.color.theme_background'))
  }
}