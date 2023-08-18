import { CommonConstants } from '../common/constants/CommonConstants';
import { IndexListItem } from '../common/bean/IndexListItem';
import { DetailListItem } from '../common/bean/DetailListItem';
import { GridItemData } from '../common/bean/GridItemData';
import CategoryViewModel from '../viewmodel/CategoryViewModel';

/**
 * Category list component.
 */
@Component
export struct CategoryListComponent {
  private scroller: Scroller = new Scroller();
  @State sideTabIndex: number = 1;

  build() {
    Row() {
      List() {
        ForEach(CategoryViewModel.getIndexListData(), (item: IndexListItem, index: number) => {
          ListItem() {
            Text(item.title)
              .fontSize($r('app.float.List_item_text_size'))
              .fontWeight(CommonConstants.INDEX_LIST_FONT_WEIGHT)
              .fontColor(this.sideTabIndex === index
                ? $r('app.color.tab_text_activated')
                : $r('app.color.list_text_normal'))
              .textAlign(TextAlign.Start)
              .margin({
                top: $r('app.float.List_item_text_margin_top'),
                bottom: $r('app.float.side_list_text_margin_bottom'),
                left: $r('app.float.side_list_text_margin_left')
              })
              .width(CommonConstants.TEXT_WIDTH_PERCENT)
              .onClick(() => {
                this.sideTabIndex = index;
                this.scroller.scrollToIndex(index);
              })
          }
        }, item => JSON.stringify(item))
      }
      .width(CommonConstants.INDEX_LIST_WIDTH_PERCENT)
      .height(CommonConstants.INDEX_LIST_HEIGHT_PERCENT)
      .margin({
        top: $r('app.float.side_list_margin_top')
      })

      Divider()
        .vertical(true)
        .color($r('app.color.divider'))
        .margin({ bottom: $r('app.float.divider_margin_bottom') })

      List({ scroller: this.scroller }) {
        ForEach(CategoryViewModel.getDetailListItems(), (item: DetailListItem) => {
          ListItem() {
            CategoryListItem({
              detailListItem: item
            })
          }
        }, item => JSON.stringify(item))
      }
      .width(CommonConstants.DETAIL_LIST_WIDTH_PERCENT)
      .height(CommonConstants.DETAIL_LIST_HEIGHT_PERCENT)
      .onScrollIndex((firstIndex: number) => {
        this.sideTabIndex = firstIndex;
      })
    }
    .layoutWeight(CommonConstants.CATEGORY_LAYOUT_WEIGHT)
  }
}

@Component
struct CategoryListItem {
  private detailListItem: DetailListItem;

  build() {
    Column() {
      Text(this.detailListItem.title)
        .width(CommonConstants.TEXT_WIDTH_PERCENT)
        .height($r('app.float.detail_list_text_height'))
        .fontSize($r('app.float.detail_list_text_size'))
        .fontColor($r('app.color.list_item_text'))
        .fontWeight(CommonConstants.DETAIL_LIST_FONT_WEIGHT)
        .margin({
          top: $r('app.float.detail_list_text_margin_top'),
          left: $r('app.float.detail_list_text_margin_left')
        })

      Grid() {
        ForEach(this.detailListItem.gridItemData, (item: GridItemData) => {
          GridItem() {
            Text(item.content)
              .width(CommonConstants.TEXT_LENGTH)
              .height($r('app.float.grid_item_height'))
              .textAlign(TextAlign.Center)
              .fontSize($r('app.float.Grid_item_text_size'))
              .fontWeight(CommonConstants.TAB_ITEM_FONT_WEIGHT)
              .align(Alignment.Center)
              .borderRadius($r('app.float.grid_item_radius'))
              .backgroundColor($r('app.color.grid_text_background'))
          }
        }, item => JSON.stringify(item))
      }
      .height($r('app.float.grid_height'))
      .columnsTemplate(CommonConstants.COLUMNS_TEMPLATE)
      .rowsTemplate(CommonConstants.ROWS_TEMPLATE)
    }
  }
}