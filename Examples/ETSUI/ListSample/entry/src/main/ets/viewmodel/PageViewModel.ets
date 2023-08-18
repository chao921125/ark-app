import { CommonConstants } from '../common/constants/CommonConstants';
import { ListItemData } from '../common/bean/ListItemData';
import { TabItemData } from '../common/bean/TabItemData';
import { ListDataSource } from './ListDataSource';

/**
 * Binds data to components and provides interfaces.
 */
export class PageViewModel {
  /**
   * Get data sources required by the LazyForEach interface.
   *
   * @return {ListDataSource} new ListDataSource(listItems)
   */
  getListDataSource(): ListDataSource {
    let listItems: Array<ListItemData> = [];
    for (let i = 0; i < CommonConstants.LIST_SIZE; i++) {
      let itemInfo: ListItemData = new ListItemData();
      itemInfo.image = $r("app.media.ic_normal");
      itemInfo.title = $r('app.string.list_item_title');
      itemInfo.subTitle = $r('app.string.list_item_sub_title');
      itemInfo.summary = $r('app.string.list_item_summary');
      itemInfo.rightArrowImage = $r("app.media.ic_right_arrow");
      listItems.push(itemInfo);
    }
    return new ListDataSource(listItems);
  }

  /**
   * Get item information for the tab.
   *
   * @return {Array<TabItemInfo>} tabItems
   */
  getTabData(): Array<TabItemData> {
    let tabItems: Array<TabItemData> = [];
    for (let i = 0; i < CommonConstants.TAB_SIZE; i++) {
      let itemInfo: TabItemData = new TabItemData();
      itemInfo.imageOriginal = $r("app.media.ic_normal");
      itemInfo.imageActivated = $r("app.media.ic_activated");
      itemInfo.title = $r('app.string.tab_title');
      tabItems.push(itemInfo);
    }
    return tabItems;
  }

  /**
   * Get detail list Data.
   *
   * @return {Array<CategoryItemInfo>} listItems
   */
  getDetailListData() {
    let listItems: Array<ListItemData> = [];
    for (let i = 0; i < CommonConstants.DETAIL_PAGE_LIST_SIZE; i++) {
      let itemInfo: ListItemData = new ListItemData();
      itemInfo.title = $r('app.string.detail_page_list_title');
      itemInfo.summary = $r('app.string.list_item_summary');
      listItems.push(itemInfo);
    }
    return listItems;
  }
}

let pageViewModel = new PageViewModel();

export default pageViewModel as PageViewModel;