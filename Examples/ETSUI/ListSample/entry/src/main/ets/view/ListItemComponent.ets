import { ListItemData } from '../common/bean/ListItemData';
import { CommonConstants } from '../common/constants/CommonConstants';

/**
 * List item information component.
 */
@Component
export struct ListItemComponent {
  private itemInfo: ListItemData;

  build() {
    Row() {
      Image(this.itemInfo.image)
        .objectFit(ImageFit.Contain)
        .width($r('app.float.image_star_width'))
        .height($r('app.float.image_star_height'))
        .margin({
          left: $r('app.float.list_image_margin_left'),
          right: $r('app.float.list_image_margin_right')
        })
      Column() {
        Text(this.itemInfo.title)
          .fontSize($r('app.float.list_item_title'))
          .fontColor($r('app.color.list_item_title'))
          .maxLines(CommonConstants.LIST_TITLE_MAX_LINES)
          .textOverflow({
            overflow: TextOverflow.Ellipsis
          })
        Text(this.itemInfo.subTitle)
          .fontSize($r('app.float.list_item_sub_title'))
          .fontColor($r('app.color.list_item_sub_title'))
          .maxLines(CommonConstants.LIST_TITLE_MAX_LINES)
          .textOverflow({
            overflow: TextOverflow.Ellipsis
          })
          .margin({
            top: $r('app.float.sub_title_margin_top')
          })
      }
      .layoutWeight(CommonConstants.LIST_TITLE_LAYOUT_WEIGHT)
      .alignItems(HorizontalAlign.Start)

      Text(this.itemInfo.summary)
        .fontSize($r('app.float.list_item_summary'))
        .margin({
          right: $r('app.float.list_summary_margin_right')
        })
        .fontColor($r('app.color.list_item_sub_title'))
      Image(this.itemInfo.rightArrowImage)
        .objectFit(ImageFit.Contain)
        .width($r('app.float.image_right_arrow_width'))
        .height($r('app.float.image_right_arrow_height'))
    }
    .height($r('app.float.list_item_height'))
  }
}