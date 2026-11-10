/**
 * 搜索设置分区 — 对齐上游 `Setting/settings/Search`
 */
import { AppSettings, DEFAULT_SETTINGS, cloneSettings } from '../../model/AppSettings'
import { ListStore } from '../../store/ListStore'
import {
  SettingSectionTitle,
  SettingSwitchRow,
  SettingDivider,
  SettingHint
} from '../../components/setting/SettingWidgets'

@Component
export struct SearchSection {
  @State settings: AppSettings = DEFAULT_SETTINGS

  aboutToAppear(): void {
    this.settings = ListStore.getSettings()
  }

  private update(patch: (s: AppSettings) => void): void {
    const next: AppSettings = cloneSettings(this.settings)
    patch(next)
    ListStore.applySettings(next)
    this.settings = next
  }

  build() {
    Column({ space: 12 }) {
      SettingSectionTitle('搜索')

      Column() {
        SettingSwitchRow('显示历史搜索记录', '搜索框下方展示最近搜索过的关键词', this.settings.showHistorySearch, (on: boolean) => {
          this.update(s => {
            s.showHistorySearch = on
          })
        })
        SettingDivider()
        SettingSwitchRow('显示热门搜索', '搜索框下方展示热门搜索词', this.settings.showHotSearch, (on: boolean) => {
          this.update(s => {
            s.showHotSearch = on
          })
        })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      SettingHint('关闭后搜索框下方不再展示历史记录与热门词，仅保留输入与结果。')
    }
    .width('100%')
  }
}
