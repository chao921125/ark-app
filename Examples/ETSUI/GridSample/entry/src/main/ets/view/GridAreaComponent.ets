import { CommonConstants } from '../common/constants/CommonConstants';
import { GridAreaContent } from '../common/bean/GridAreaContent';
import { GridItemData } from '../common/bean/GridItemData';

/**
 * GridView component display and layout
 */
@Component
export struct GridAreaComponent {
  private gridAreaContents: Array<GridAreaContent>;

  build() {
    Column() {
      ForEach(this.gridAreaContents, (gridAreaContent: GridAreaContent) => {
        Grid() {
          ForEach(gridAreaContent.gridItems, (item: GridItemData) => {
            GridItem() {
              this.GridItemView(item)
            }
          }, item => JSON.stringify(item))
        }
        .columnsTemplate(CommonConstants.COLUMNS_TEMPLATE)
        .height(gridAreaContent.gridHeight)
        .touchable(false)
        .padding({
          bottom: $r('app.float.grid_padding_bottom')
        })
      }, gridAreaContent => JSON.stringify(gridAreaContent))
    }
  }

  @Builder GridItemView(item: GridItemData) {
    Flex({
      direction: FlexDirection.Column,
      alignItems: ItemAlign.Center,
      justifyContent: FlexAlign.Center
    }) {
      Image(item.image)
        .objectFit(ImageFit.Contain)
        .width($r('app.float.image_width'))
        .height($r('app.float.image_height'))

      Text(item.title)
        .height($r('app.float.grid_item_text_height'))
        .fontSize($r('app.float.grid_item_text_size'))
        .fontWeight(CommonConstants.GRID_ITEM_FONT_WEIGHT)
        .fontColor($r('app.color.grid_text'))
        .align(Alignment.Center)
        .margin({
          top: $r('app.float.grid_text_margin_top'),
          bottom: $r('app.float.grid_text_margin_bottom')
        })
    }
    .width($r('app.float.grid_item_width'))
    .height($r('app.float.grid_item_height'))
    .padding({ top: $r('app.float.grid_item_padding_top') })
  }
}