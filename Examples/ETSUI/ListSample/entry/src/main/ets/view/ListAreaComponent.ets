import router from '@ohos.router';
import { CommonConstants } from '../common/constants/CommonConstants';
import { ListItemData } from '../common/bean/ListItemData';
import { ListItemComponent } from './ListItemComponent';
import PageViewModel from '../viewmodel/PageViewModel';

/**
 * List area of the main tab content.
 */
@Component
export struct ListAreaComponent {
  build() {
    Column() {
      List() {
        LazyForEach(PageViewModel.getListDataSource(), (item: ListItemData) => {
          ListItem() {
            ListItemComponent({ itemInfo: item })
          }
          .onClick(() => {
            router.push({
              url: CommonConstants.PAGE_NAME,
              params: {
                data: item.title
              }
            });
          })
        }, item => JSON.stringify(item))
      }
      .width(CommonConstants.LIST_WIDTH_PERCENT)
      .divider({
        strokeWidth: $r('app.float.divider_height'),
        color: $r('app.color.list_divider'),
        startMargin: $r('app.float.list_divider_start_margin'),
        endMargin: $r('app.float.list_divider_end_margin')
      })
      .margin({ bottom: $r('app.float.tab_bar_height') })
    }
    .width(CommonConstants.COLUMN_WIDTH_PERCENT)
    .height(CommonConstants.COLUMN_HEIGHT_PERCENT)
  }
}