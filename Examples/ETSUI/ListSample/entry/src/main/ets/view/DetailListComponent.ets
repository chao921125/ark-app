import PageViewModel from '../viewmodel/PageViewModel';
import { ListItemData } from '../common/bean/ListItemData';
import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * Detail page list component.
 */
@Component
export struct DetailListComponent {
  build() {
    Column() {
      List() {
        ForEach(PageViewModel.getDetailListData(), (item: ListItemData) => {
          ListItem() {
            Row() {
              Text(item.title)
                .fontSize($r('app.float.list_item_title'))
                .fontColor($r('app.color.list_item_title'))
              Blank()
              Text(item.summary)
                .fontSize($r('app.float.list_item_sub_title'))
                .fontColor($r('app.color.list_item_sub_title'))
            }
            .width(CommonConstants.ROW_WIDTH_PERCENT)
            .height($r('app.float.detail_list_item_height'))
          }
        }, item => JSON.stringify(item));
      }
      .divider({
        strokeWidth: $r('app.float.divider_height'),
        color: $r('app.color.list_divider')
      })
    }
    .width(CommonConstants.LIST_WIDTH_PERCENT)
    .padding({
      top: $r('app.float.detail_list_padding_vertical'),
      bottom: $r('app.float.detail_list_padding_vertical'),
      left: $r('app.float.detail_list_padding_horizontal'),
      right: $r('app.float.detail_list_padding_horizontal')
    })
    .margin({ top: $r('app.float.list_margin_top') })
    .backgroundColor($r('app.color.list_content_background'))
    .borderRadius($r('app.float.list_radius'))
  }
}