import { CommonConstants } from '../common/constants/CommonConstants';
import { IndexListItem } from '../common/bean/IndexListItem';
import { TabItem } from '../common/bean/TabItem';
import { DetailListItem } from '../common/bean/DetailListItem';
import { GridItemData } from '../common/bean/GridItemData';

/**
 * Category ability view model.
 */
export class CategoryViewModel {
  /**
   * Get index list data on the left.
   *
   * @return {Array<IndexListItem>} indexListItems
   */
  getIndexListData() {
    let indexListItems: Array<IndexListItem> = [];
    for (let index = 1; index <= CommonConstants.LIST_SIZE; index++) {
      let indexListItem = new IndexListItem();
      indexListItem.title = $r('app.string.list_item_text', index);
      indexListItems.push(indexListItem);
    }
    return indexListItems;
  }

  /**
   * Get tab item data.
   *
   * @return {Array<TabItem>} tabItems
   */
  getTabItems() {
    let tabItems: Array<TabItem> = [];
    for (let index = 0; index < CommonConstants.TAB_BAR_SIZE; index++) {
      let tabItem = new TabItem();
      tabItem.index = index;
      tabItem.title = $r('app.string.tab_text');
      tabItem.imageOriginal = $r("app.media.ic_tab_normal");
      tabItem.imageActivated = $r("app.media.ic_tab_activated");
      tabItems.push(tabItem);
    }
    return tabItems;
  }

  /**
   * Get detail list item info.
   *
   * @return {Array<DetailListItem>} detailListItems
   */
  getDetailListItems() {
    let detailListItems: Array<DetailListItem> = [];
    for (let i = 0; i < CommonConstants.LIST_SIZE; i++) {
      let detailListItem = new DetailListItem();
      detailListItem.title = $r('app.string.detail_list_item_text');
      detailListItem.gridItemData = this.getGridItems();
      detailListItems.push(detailListItem);
    }
    return detailListItems;
  }

  /**
   * Get grid item info.
   *
   * @return {Array<GridItemData>} gridData
   */
  private getGridItems() {
    let gridData: Array<GridItemData> = [];
    for (let i = 0; i < CommonConstants.GRID_ITEM_SIZE; i++) {
      let gridItemData = new GridItemData();
      gridItemData.content = $r('app.string.grid_item_text');
      gridData.push(gridItemData);
    }
    return gridData;
  }
}

let categoryViewModel = new CategoryViewModel();

export default categoryViewModel as CategoryViewModel;