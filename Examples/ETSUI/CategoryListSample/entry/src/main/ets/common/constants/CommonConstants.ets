/**
 * Common constants for all features.
 */
export class CommonConstants {
  /**
   * The placeholder of search component. Currently, component interfaces do not support the Resource type.
   * Therefore, you need to define constants. The default prompt in the search box does not support
   * internationalization.
   */
  static readonly SEARCH_PLACEHOLDER = 'Search...';

  /**
   * The font family of search component.
   */
  static readonly SEARCH_FONT_FAMILY = 'serif';

  /**
   * Search weight.
   */
  static readonly SEARCH_WEIGHT: number = 10;

  /**
   * Detail page url.
   */
  static readonly DETAIL_PAGE = 'pages/DetailPage';

  /**
   * This is key param of data.
   */
  static readonly KEY_PARAM_DATA = 'data';

  /**
   * Scroll weight.
   */
  static readonly SCROLL_WEIGHT: number = 1;

  /**
   * The initial value of category size which is increased by one.
   */
  static readonly CATEGORY_INCREMENTAL_STEP: number = 1;

  /**
   * Category content list size.
   */
  static readonly CATEGORY_CONTENT_LIST_SIZE: number = 6;

  /**
   * Detail page list size.
   */
  static readonly DETAIL_PAGE_LIST_SIZE: number = 2;

  /**
   * Row width.
   */
  static readonly ROW_WIDTH_PERCENT = '100%';

  /**
   * Text navigation title text width.
   */
  static readonly NAVIGATION_TEXT_WIDTH_PERCENT = '100%';

  /**
   * Navigation width.
   */
  static readonly NAVIGATION_WIDTH_PERCENT = '100%';

  /**
  * Detail column title text width.
  */
  static readonly DETAIL_COLUMN_WIDTH_PERCENT = '100%';

  /**
   * Detail column height.
   */
  static readonly DETAIL_COLUMN_HEIGHT_PERCENT = '100%';

  /**
  * Detail list width.
  */
  static readonly DETAIL_LIST_WIDTH_PERCENT = '93.3%';
}