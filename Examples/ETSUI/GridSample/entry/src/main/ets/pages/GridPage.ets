import { CommonConstants } from '../common/constants/CommonConstants';
import { GridAreaComponent } from '../view/GridAreaComponent';
import GridViewModel from '../viewmodel/GridViewModel';

/**
 * This module template implements Grid functions.
 * The template structure is from top to bottom,include Grid and Text.
 * Developers can add corresponding data as needed after creating a template.
 */
@Entry
@Component
struct GridPage {
  build() {
    Column() {
      Navigation()
        .width(CommonConstants.NAVIGATION_WIDTH_PERCENT)
        .height($r('app.float.navigation_height'))
        .title(this.NavigationTitle())
        .titleMode(NavigationTitleMode.Mini)
        .align(Alignment.Start)

      Scroll() {
        Column() {
          GridAreaComponent({ gridAreaContents: GridViewModel.getTopGridAreaData() })

          Text($r('app.string.grid_content_text'))
            .textAlign(TextAlign.Start)
            .fontSize($r('app.float.sub_text_size'))
            .fontWeight(CommonConstants.TEXT_FONT_WEIGHT)
            .fontColor($r('app.color.grid_text'))
            .width(CommonConstants.TEXT_WIDTH_PERCENT)
            .height($r('app.float.grid_text_height'))

          GridAreaComponent({ gridAreaContents: GridViewModel.getBottomGridAreaData() })
        }
      }
      .layoutWeight(CommonConstants.SCROLL_LAYOUT_WEIGHT)
      .padding({
        left: $r('app.float.grid_content_padding_left'),
        right: $r('app.float.grid_content_padding_right')
      })
    }
    .alignItems(HorizontalAlign.Start)
    .backgroundColor($r('app.color.grid_background'))
    .height(CommonConstants.GRID_PAGE_HEIGHT_PERCENT)
    .padding({
      bottom: $r('app.float.grid_page_padding_bottom')
    })
  }

  @Builder NavigationTitle() {
    Column() {
      Text($r('app.string.navigation_title'))
        .height($r('app.float.title_height'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(CommonConstants.TITLE_FONT_WEIGHT)
    }
  }
}