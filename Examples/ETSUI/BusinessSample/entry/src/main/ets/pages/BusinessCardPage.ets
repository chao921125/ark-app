import { TabItemData } from '../common/bean/TabItemData';
import { CommonConstants } from '../common/constants/CommonConstants';
import { CardContentComponent } from '../view/CardContentComponent';
import BusinessViewModel from '../viewmodel/BusinessViewModel';

/**
 * This template implements the business card function and consists of three components.The top part is the
 * Navigation, and the bottom part is the Tab. The middle card content shows the business information.
 * Developers can enrich the function of Navigation and Tab, and add relevant business information to the list.
 */
@Entry
@Component
struct BusinessCardPage {
  @State currentIndex: number = 3;

  build() {
    Column() {
      Navigation()
        .title(this.NavigationTitle())
        .hideToolBar(true)
        .height($r('app.float.title_height'))
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)

      Tabs({
        index: this.currentIndex,
        barPosition: BarPosition.End
      }) {
        ForEach(BusinessViewModel.getTabItems(), (item: TabItemData) => {
          TabContent() {
            CardContentComponent()
          }
          .tabBar(this.CardTab(item))
        }, item => JSON.stringify(item))
      }
      .layoutWeight(CommonConstants.TABS_WEIGHT)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.currentIndex = index;
      })
    }
    .backgroundColor($r('app.color.common_background'))
  }

  @Builder CardTab(item: TabItemData) {
    Column() {
      Image(this.currentIndex === item.index ? item.imageActivated : item.imageOriginal)
        .width($r('app.float.tab_title_image'))
        .height($r('app.float.tab_title_image'))
        .objectFit(ImageFit.Contain)
        .margin({
          top: $r('app.float.tab_image_margin_top'),
          bottom: $r('app.float.tab_image_margin_bottom')
        })
      Text(item.title)
        .fontSize($r('app.float.tab_text_size'))
        .fontColor(this.currentIndex === item.index
          ? $r('app.color.tab_text_activated')
          : $r('app.color.tab_text_normal'))
    }
    .justifyContent(FlexAlign.Center)
    .width(CommonConstants.TAB_BAR_WIDTH_PERCENT)
    .height($r('app.float.bar_height'))
  }

  @Builder NavigationTitle() {
    Text($r('app.string.page_title'))
      .fontSize($r('app.float.tab_title_size'))
      .fontColor($r('app.color.title'))
      .fontWeight(CommonConstants.TITLE_FONT_WEIGHT)
  }
}