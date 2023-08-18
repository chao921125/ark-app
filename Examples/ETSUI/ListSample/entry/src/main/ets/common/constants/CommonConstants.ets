/**
 * Common constants for all features.
 */
export class CommonConstants {
  /**
   * Search font weight.
   */
  static readonly SEARCH_FONT_WEIGHT: number = 10;

  /**
   * The placeholder of search component.Currently, component interfaces do not support the Resource type.
   * Therefore, you need to define constants. The default prompt in the search box does not support
   * internationalization.
   */
  static readonly SEARCH_PLACEHOLDER: string = 'Search...';

  /**
   * The font family of search component.
   */
  static readonly SEARCH_FONT_FAMILY: string = 'serif';

  /**
   * The percentage of search component.
   */
  static readonly SEARCH_WIDTH_PERCENT: string = '100%';

  /**
   * Number of tab contents.
   */
  static readonly TAB_SIZE: number = 5;

  /**
   * Layout weight of the bottom tab.
   */
  static readonly TAB_LAYOUT_WEIGHT: number = 1;

  /**
   * Number of detail list contents.
   */
  static readonly DETAIL_PAGE_LIST_SIZE: number = 2;

  /**
   * Number of list contents.
   */
  static readonly LIST_SIZE: number = 20;

  /**
   * Layout weight of the list title.
   */
  static readonly LIST_TITLE_LAYOUT_WEIGHT: number = 1;

  /**
   * Max lines of the list title.
   */
  static readonly LIST_TITLE_MAX_LINES: number = 1;

  /**
   * Detail page url.
   */
  static readonly PAGE_NAME: string = 'pages/DetailPage';

  /**
   * Key to transfer parameters when replace pages.
   */
  static readonly KEY_PARAM_DATA: string = 'data';

  /**
   * The percentage of tabs component.
   */
  static readonly TABS_WIDTH_PERCENT: string = '100%';

  /**
   * The percentage of navigation title component.
   */
  static readonly NAVIGATION_TITLE_WIDTH_PERCENT: string = '100%';

  /**
   * The percentage of navigation component.
   */
  static readonly NAVIGATION_WIDTH_PERCENT: string = '100%';

  /**
   * The percentage of list component.
   */
  static readonly LIST_WIDTH_PERCENT: string = '93.3%';

  /**
   * The percentage of column component.
   */
  static readonly COLUMN_WIDTH_PERCENT: string = '100%';

  /**
   * The percentage of height in column component.
   */
  static readonly COLUMN_HEIGHT_PERCENT: string = '100%';

  /**
   * The percentage of width in row component.
   */
  static readonly ROW_WIDTH_PERCENT: string = '100%';
}