/**
 * 列表设置分区 — 对齐上游 `Setting/settings/List`
 */
import { AppSettings, DEFAULT_SETTINGS, cloneSettings, AddMusicLocationType } from '../../model/AppSettings'
import { ListStore } from '../../store/ListStore'
import { SettingOptionSheet } from '../../components/setting/SettingOptionSheet'
import {
  SettingSectionTitle,
  SettingSwitchRow,
  SettingRadioRow,
  SettingDivider,
  SettingHint
} from '../../components/setting/SettingWidgets'

@Component
export struct ListSection {
  @State settings: AppSettings = DEFAULT_SETTINGS
  @State showLocationSheet: boolean = false

  private locationOptions: string[] = ['添加到顶部', '添加到底部']

  aboutToAppear(): void {
    this.settings = ListStore.getSettings()
  }

  private update(patch: (s: AppSettings) => void): void {
    const next: AppSettings = cloneSettings(this.settings)
    patch(next)
    ListStore.applySettings(next)
    this.settings = next
  }

  private locationLabel(): string {
    return this.settings.addMusicLocationType == 'top' ? '添加到顶部' : '添加到底部'
  }

  build() {
    Column({ space: 12 }) {
      SettingSectionTitle('列表')

      Column() {
        SettingSwitchRow('显示歌曲时长', '在歌曲列表中显示每首歌的时长', this.settings.showInterval, (on: boolean) => {
          this.update(s => {
            s.showInterval = on
          })
        })
        SettingDivider()
        SettingSwitchRow('显示歌曲专辑名', '在歌曲列表中显示专辑名', this.settings.showAlbumName, (on: boolean) => {
          this.update(s => {
            s.showAlbumName = on
          })
        })
        SettingDivider()
        SettingRadioRow('添加歌曲到列表时的位置', this.locationLabel(), () => {
          this.showLocationSheet = true
        })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      SettingHint('「添加位置」对搜索结果加入歌单、本地导入加入歌单均生效。')
    }
    .width('100%')
    .bindSheet($$this.showLocationSheet, this.LocationSheetBuilder(), {
      height: 300,
      dragBar: true,
      backgroundColor: $r('app.color.bg_card'),
      onDisappear: () => {
        this.showLocationSheet = false
      }
    })
  }

  @Builder
  LocationSheetBuilder() {
    SettingOptionSheet({
      title: '添加歌曲到列表时的位置',
      options: this.locationOptions,
      selectedIndex: this.settings.addMusicLocationType == 'top' ? 0 : 1,
      onSelect: (index: number) => {
        const type: AddMusicLocationType = index == 0 ? 'top' : 'bottom'
        this.update(s => {
          s.addMusicLocationType = type
        })
      },
      onClose: () => {
        this.showLocationSheet = false
      }
    })
  }
}
