/**
 * 播放设置分区 — 对齐上游 `Setting/settings/Player`
 */
import { AppSettings, DEFAULT_SETTINGS, cloneSettings, PlayMode, PlayQuality } from '../../model/AppSettings'
import { ListStore } from '../../store/ListStore'
import { PlayerFacade } from '../../app/PlayerFacade'
import { SettingOptionSheet } from '../../components/setting/SettingOptionSheet'
import {
  SettingSectionTitle,
  SettingSwitchRow,
  SettingRadioRow,
  SettingSliderRow,
  SettingDivider,
  SettingHint
} from '../../components/setting/SettingWidgets'

@Component
export struct PlayerSection {
  @State settings: AppSettings = DEFAULT_SETTINGS
  /** 单一弹层 + 类型标记：避免同一组件挂两个 bindSheet（后者会覆盖前者） */
  @State showSheet: boolean = false
  @State sheetKind: string = ''

  private modeOptions: string[] = ['列表循环', '列表随机', '单曲循环']
  private qualityOptions: string[] = ['标准 128k', '高清 320k', '无损 FLAC', 'Hi-Res']

  aboutToAppear(): void {
    this.settings = ListStore.getSettings()
  }

  private update(patch: (s: AppSettings) => void): void {
    const next: AppSettings = cloneSettings(this.settings)
    patch(next)
    ListStore.applySettings(next)
    this.settings = next
  }

  private modeLabel(): string {
    if (this.settings.playMode == 'listRandom') {
      return '列表随机'
    }
    if (this.settings.playMode == 'singleLoop') {
      return '单曲循环'
    }
    return '列表循环'
  }

  private qualityLabel(): string {
    if (this.settings.playQuality == '320k') {
      return '标准 320k'
    }
    if (this.settings.playQuality == 'flac') {
      return '无损 FLAC'
    }
    if (this.settings.playQuality == 'flac24bit') {
      return 'Hi-Res'
    }
    return '标准 128k'
  }

  build() {
    Column({ space: 12 }) {
      SettingSectionTitle('播放')

      Column() {
        SettingRadioRow('播放模式', this.modeLabel(), () => {
          this.sheetKind = 'mode'
          this.showSheet = true
        })
        SettingDivider()
        SettingRadioRow('优先播放的音质', this.qualityLabel(), () => {
          this.sheetKind = 'quality'
          this.showSheet = true
        })
        SettingDivider()
        SettingSliderRow('音量', this.settings.volume, 0, 100, 1, (value: number) => {
          // 立即生效 + 落盘防抖（编排层负责持久化）
          PlayerFacade.setVolume(Math.round(value))
          this.settings.volume = Math.round(value)
        })
        SettingDivider()
        SettingSwitchRow('记住播放进度', '下次启动时恢复上次播放的歌曲与进度', this.settings.restorePlayProgress,
          (on: boolean) => {
            this.update(s => {
              s.restorePlayProgress = on
            })
          })
        SettingDivider()
        SettingSwitchRow('其他应用播放声音时自动暂停', '与其它应用共享音频焦点（对齐上游音频焦点处理）',
          this.settings.handleAudioFocus, (on: boolean) => {
            this.update(s => {
              s.handleAudioFocus = on
            })
          })
        SettingDivider()
        SettingSwitchRow('通知栏显示专辑封面', '在媒体通知中展示歌曲封面', this.settings.showNotificationImage,
          (on: boolean) => {
            this.update(s => {
              s.showNotificationImage = on
            })
          })
        SettingDivider()
        SettingSwitchRow('自动清空已播放列表', '随机模式下手动选歌时，已播放的歌曲重新参与随机',
          this.settings.autoCleanPlayedList, (on: boolean) => {
            this.update(s => {
              s.autoCleanPlayedList = on
            })
          })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      SettingHint('上游还提供音频卸载、蓝牙歌词、歌词翻译/罗马音、繁简转换、缓存上限等选项，\n依赖本项目尚未具备的音频栈与歌词增强能力，故此处不提供。')
    }
    .width('100%')
    .bindSheet($$this.showSheet, this.SheetBuilder(), {
      height: 360,
      dragBar: true,
      backgroundColor: $r('app.color.bg_card'),
      onDisappear: () => {
        this.showSheet = false
      }
    })
  }

  @Builder
  SheetBuilder() {
    if (this.sheetKind == 'quality') {
      SettingOptionSheet({
        title: '优先播放的音质',
        options: this.qualityOptions,
        selectedIndex: this.settings.playQuality == '128k' ? 0 :
          (this.settings.playQuality == '320k' ? 1 : (this.settings.playQuality == 'flac' ? 2 : 3)),
        onSelect: (index: number) => {
          const q: PlayQuality = index == 0 ? '128k' : (index == 1 ? '320k' : (index == 2 ? 'flac' : 'flac24bit'))
          void PlayerFacade.setPlayQuality(q)
          this.settings.playQuality = q
        },
        onClose: () => {
          this.showSheet = false
        }
      })
    } else {
      SettingOptionSheet({
        title: '播放模式',
        options: this.modeOptions,
        selectedIndex: this.settings.playMode == 'listLoop' ? 0 : (this.settings.playMode == 'listRandom' ? 1 : 2),
        onSelect: (index: number) => {
          const mode: PlayMode = index == 0 ? 'listLoop' : (index == 1 ? 'listRandom' : 'singleLoop')
          void PlayerFacade.setMode(mode)
          this.settings.playMode = mode
        },
        onClose: () => {
          this.showSheet = false
        }
      })
    }
  }
}
