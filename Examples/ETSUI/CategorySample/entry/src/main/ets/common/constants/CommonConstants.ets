/**
 * Common constants for all features.
 */
export class CommonConstants {
  /**
   * Search weight.
   */
  static readonly SEARCH_WEIGHT: number = 10;

  /**
   * The placeholder of search component.Currently, component interfaces do not support the Resource type.
   * Therefore, you need to define constants. The default prompt in the search box does not support
   * internationalization.
   */
  static readonly SEARCH_PLACEHOLDER: string = 'Search...';

  /**
   * Search font family.
   */
  static readonly SEARCH_FONT_FAMILY: string = 'serif';

  /**
   * The font weight of text in the index list.
   */
  static readonly INDEX_LIST_FONT_WEIGHT: number = 400;

  /**
   * Size of index list and detail list.
   */
  static readonly LIST_SIZE: number = 6;

  /**
   * The percentage of the index list width.
   */
  static readonly INDEX_LIST_WIDTH_PERCENT: string = '30%';

  /**
   * The percentage of the index list height.
   */
  static readonly INDEX_LIST_HEIGHT_PERCENT: string = '100%';

  /**
   * The font weight of text in the detail list.
   */
  static readonly DETAIL_LIST_FONT_WEIGHT: number = 500;

  /**
   * The percentage of the detail list width.
   */
  static readonly DETAIL_LIST_WIDTH_PERCENT: string = '70%';

  /**
   * The percentage of the detail list height.
   */
  static readonly DETAIL_LIST_HEIGHT_PERCENT: string = '100%';

  /**
   * The font weight of text in the tab.
   */
  static readonly TAB_ITEM_FONT_WEIGHT: number = 500;

  /**
   * Size of tab bar.
   */
  static readonly TAB_BAR_SIZE: number = 5;

  /**
   * Tab layout weight.
   */
  static readonly TAB_LAYOUT_WEIGHT: number = 1;

  /**
   * The percentage of the tab bar width.
   */
  static readonly TAB_BAR_WIDTH_PERCENT: string = '100%';

  /**
   * The font weight of navigation title.
   */
  static readonly TITLE_FONT_WEIGHT: number = 500;

  /**
   * The font weight of navigation subtitle.
   */
  static readonly SUBTITLE_FONT_WEIGHT: number = 400;

  /**
   * Size of grid item.
   */
  static readonly GRID_ITEM_SIZE: number = 6;

  /**
   * Category layout weight.
   */
  static readonly CATEGORY_LAYOUT_WEIGHT: number = 1;

  /**
   * Text length.
   */
  static readonly TEXT_LENGTH: number = 100;

  /**
   * Grid columns template.
   */
  static readonly COLUMNS_TEMPLATE: string = '1fr 1fr';

  /**
   * Grid rows template.
   */
  static readonly ROWS_TEMPLATE: string = '1fr 1fr 1fr';

  /**
   * The percentage of the text width.
   */
  static readonly TEXT_WIDTH_PERCENT: string = '100%';

  /**
   * The percentage of the navigation width.
   */
  static readonly NAVIGATION_WIDTH_PERCENT: string = '100%';
}