import router from '@ohos.router';
import { ListItemData } from '../common/bean/ListItemData';
import { WidgetType } from '../common/bean/WidgetType';
import { CommonConstants } from '../common/constants/CommonConstants';
import { CardItemComponent } from './CardItemComponent';
import BusinessViewModel from '../viewmodel/BusinessViewModel';

/**
 * Card content contains the information list.
 */
@Component
export struct CardContentComponent {
  build() {
    Scroll() {
      Stack({ alignContent: Alignment.Top }) {
        Rect()
          .width(CommonConstants.RECT_WIDTH_PERCENT)
          .height($r('app.float.card_rect_height'))
          .margin({ top: $r('app.float.card_margin_top') })
          .fill($r('app.color.card_background'))
          .radius(CommonConstants.RECT_RADIUS)

        Column() {
          List() {
            ForEach(BusinessViewModel.getListItems(), (item: ListItemData) => {
              ListItem() {
                CardItemComponent({ cardItem: item })
              }
              .onClick(() => this.openDetailPage(item))
            }, item => JSON.stringify(item))
          }
          .divider({
            strokeWidth: $r('app.float.list_divider_width'),
            color: $r('app.color.divider'),
            startMargin: $r('app.float.card_divider_margin'),
            endMargin: $r('app.float.card_divider_margin')
          })
        }
        .backgroundColor($r('app.color.card_background'))
        .margin({ top: $r('app.float.card_list_margin_top') })

        Column() {
          Image($r("app.media.ic_user"))
            .width($r('app.float.card_user_icon'))
            .height($r('app.float.card_user_icon'))
            .objectFit(ImageFit.Contain)
          Text($r('app.string.user_name'))
            .fontSize($r('app.float.card_user_name_size'))
            .margin({ top: $r('app.float.card_user_name_margin_top') })
        }
        .margin({ top: $r('app.float.card_user_icon_margin_top') })
      }
    }
    .edgeEffect(EdgeEffect.Spring)
    .width(CommonConstants.SCROLL_WIDTH_PERCENT)
    .height(CommonConstants.SCROLL_HEIGHT_PERCENT)
  }

  openDetailPage(item: ListItemData) {
    if (item.widget !== WidgetType.TOGGLE) {
      router.push({
        url: CommonConstants.DETAIL_ROUTER_URL,
        params: {
          title: item.title
        }
      });
    }
  }
}