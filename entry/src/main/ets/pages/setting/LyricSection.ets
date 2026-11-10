/**
 * 歌词设置分区 — 对齐上游 `Setting/settings/LyricDesktop`（本项目为应用内 + 悬浮歌词）
 */
import { AppSettings, DEFAULT_SETTINGS, cloneSettings } from '../../model/AppSettings'
import { ListStore } from '../../store/ListStore'
import { SettingSectionTitle, SettingSwitchRow, SettingSliderRow, SettingDivider, SettingHint } from '../../components/setting/SettingWidgets'

@Component
export struct LyricSection {
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

  /** 悬浮歌词模式提示（真悬浮窗 / 应用内歌词条） */
  private floatLyricModeHint(): string {
    if (!this.settings.showFloatLyric) {
      return '开启后悬浮显示当前歌词行'
    }
    return AppStorage.get<boolean>('floatLyricWindowActive') == true
      ? '桌面悬浮窗模式（可拖动，退出应用仍显示）'
      : '应用内歌词条模式（未授予悬浮窗权限）'
  }

  build() {
    Column({ space: 12 }) {
      SettingSectionTitle('歌词')

      Column() {
        SettingSwitchRow('显示悬浮歌词', this.floatLyricModeHint(), this.settings.showFloatLyric, (on: boolean) => {
          // 走 ListStore：持久化 + 真悬浮窗创建/销毁（失败回落应用内条）
          void ListStore.setShowFloatLyric(on)
          this.settings.showFloatLyric = on
        })
        SettingDivider()
        SettingSliderRow('歌词字号', this.settings.lyricFontSize, 12, 28, 1, (value: number) => {
          this.update(s => {
            s.lyricFontSize = Math.round(value)
          })
        })
        SettingDivider()
        SettingSliderRow('歌词行间距', this.settings.lyricLineGap, 8, 32, 1, (value: number) => {
          this.update(s => {
            s.lyricLineGap = Math.round(value)
          })
        })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      SettingHint('上游的桌面歌词还提供主题色、透明度、位置、单行等样式项；\n本项目悬浮窗暂未开放样式定制，故此处不提供。')
    }
    .width('100%')
  }
}
