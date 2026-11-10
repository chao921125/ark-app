/**
 * 数据同步分区 — 对齐上游 `Setting/settings/Sync`
 *
 * 本项目的 PC 同步（三期）此前在设置页被 `if (false)` 隐藏，功能是完整的，
 * 本轮把它恢复到这里并独立成区。
 */
import { promptAction } from '@kit.ArkUI'

import { hilog } from '@kit.PerformanceAnalysisKit'
import { SyncManager, BusinessErrorLike } from '../../sync/SyncManager'
import { SyncStatus, SyncMode } from '../../sync/SyncConstants'
import {
  SettingSectionTitle,
  SettingInputRow,
  SettingActionRow,
  SettingDivider,
  SettingHint
} from '../../components/setting/SettingWidgets'

const TAG: string = 'SyncSection'
const DOMAIN: number = 0x0001

@Component
export struct SyncSection {
  @State syncHost: string = ''
  @State syncAuthCode: string = ''
  @State syncConnecting: boolean = false
  @State syncStatus: SyncStatus = { status: false, message: '', address: '', serverName: '' }
  @StorageLink('syncStatusRev') @Watch('refreshSyncStatus') syncStatusRev: number = 0
  @StorageLink('syncModeRequestRev') @Watch('onSyncModeRequest') syncModeRequestRev: number = 0
  @State showSyncModeSheet: boolean = false
  @State syncModeServerName: string = ''

  aboutToAppear(): void {
    this.refreshSyncStatus()
    void this.loadSavedSyncHost()
  }

  private async loadSavedSyncHost(): Promise<void> {
    try {
      this.syncHost = await SyncManager.getSavedHost()
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'load saved sync host failed: %{public}s', JSON.stringify(e))
      this.syncHost = ''
    }
  }

  refreshSyncStatus(): void {
    try {
      const json = AppStorage.get<string>('syncStatusJson') ?? ''
      if (json.length > 0) {
        this.syncStatus = JSON.parse(json) as SyncStatus
      } else {
        this.syncStatus = SyncManager.getStatus()
      }
    } catch (ignored) {
      this.syncStatus = SyncManager.getStatus()
    }
  }

  onSyncModeRequest(): void {
    this.syncModeServerName = AppStorage.get<string>('syncModeServerName') ?? ''
    this.showSyncModeSheet = true
  }

  private syncStatusText(): string {
    if (this.syncStatus.status) {
      return `已连接 ${this.syncStatus.serverName}`
    }
    if (this.syncStatus.message.length > 0) {
      return this.syncStatus.message
    }
    return '未连接'
  }

  private async connectSync(): Promise<void> {
    if (this.syncHost.trim().length == 0) {
      promptAction.showToast({ message: '请输入同步地址（桌面版设置-数据同步中查看）', duration: 2500 })
      return
    }
    this.syncConnecting = true
    try {
      await SyncManager.connectServer(this.syncHost, this.syncAuthCode.trim().length > 0 ? this.syncAuthCode.trim() : undefined)
      this.syncAuthCode = ''
    } catch (e) {
      const err = e as BusinessErrorLike
      promptAction.showToast({ message: `连接失败：${err.message ?? '未知错误'}`, duration: 3000 })
    } finally {
      this.syncConnecting = false
    }
  }

  build() {
    Column({ space: 12 }) {
      SettingSectionTitle('数据同步')

      Column({ space: 10 }) {
        SettingActionRow('同步状态', '', this.syncStatusText(), () => {
          this.refreshSyncStatus()
        })
        SettingDivider()
        SettingInputRow('同步服务地址（桌面版 设置-数据同步）', this.syncHost, 'http://192.168.1.5:23332',
          (value: string) => {
            this.syncHost = value
          })
        SettingDivider()
        SettingInputRow('连接码（首次连接需要，之后自动免密）', this.syncAuthCode, '连接码', (value: string) => {
          this.syncAuthCode = value
        })

        Row({ space: 10 }) {
          Button(this.syncConnecting ? '连接中…' : (this.syncStatus.status ? '重新连接' : '连接'))
            .layoutWeight(1)
            .height(38)
            .fontSize(13)
            .type(ButtonType.Capsule)
            .backgroundColor($r('app.color.theme_primary'))
            .fontColor(Color.White)
            .enabled(!this.syncConnecting)
            .onClick(() => {
              void this.connectSync()
            })
          Button('断开')
            .layoutWeight(1)
            .height(38)
            .fontSize(13)
            .type(ButtonType.Capsule)
            .backgroundColor($r('app.color.bg_page'))
            .fontColor($r('app.color.text_primary'))
            .enabled(this.syncStatus.status)
            .onClick(() => {
              void SyncManager.disconnectServer()
            })
        }
        .width('100%')

        SettingHint('首次连接时会弹出同步模式选择。歌单改动在下次连接时自动合并同步。')
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))
    }
    .width('100%')
    .bindSheet($$this.showSyncModeSheet, this.SyncModeSheetBuilder(), {
      height: 380,
      dragBar: true,
      backgroundColor: $r('app.color.bg_card'),
      onDisappear: () => {
        if (this.showSyncModeSheet) {
          this.showSyncModeSheet = false
          SyncManager.cancelSyncMode()
        }
      }
    })
  }

  @Builder
  SyncModeSheetBuilder() {
    Column() {
      Text('选择同步模式')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 2 })
      Text(`与「${this.syncModeServerName}」同步歌单`)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

      Text('合并').fontSize(13).fontColor($r('app.color.text_secondary'))
        .width('100%').padding({ left: 16 })
      Row({ space: 10 }) {
        Button('保留两端更多')
          .layoutWeight(1).height(40).fontSize(13).type(ButtonType.Capsule)
          .backgroundColor($r('app.color.bg_page')).fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.showSyncModeSheet = false
            SyncManager.resolveSyncMode('merge_local_remote' as SyncMode)
          })
        Button('以手机为准')
          .layoutWeight(1).height(40).fontSize(13).type(ButtonType.Capsule)
          .backgroundColor($r('app.color.bg_page')).fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.showSyncModeSheet = false
            SyncManager.resolveSyncMode('merge_remote_local' as SyncMode)
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 8 })

      Text('覆盖').fontSize(13).fontColor($r('app.color.text_secondary'))
        .width('100%').padding({ left: 16 })
      Row({ space: 10 }) {
        Button('手机覆盖电脑')
          .layoutWeight(1).height(40).fontSize(13).type(ButtonType.Capsule)
          .backgroundColor($r('app.color.bg_page')).fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.showSyncModeSheet = false
            SyncManager.resolveSyncMode('overwrite_local_remote' as SyncMode)
          })
        Button('电脑覆盖手机')
          .layoutWeight(1).height(40).fontSize(13).type(ButtonType.Capsule)
          .backgroundColor($r('app.color.bg_page')).fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.showSyncModeSheet = false
            SyncManager.resolveSyncMode('overwrite_remote_local' as SyncMode)
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 8 })

      Text('取消本次同步')
        .fontSize(13)
        .fontColor('#E05454')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(12)
        .onClick(() => {
          this.showSyncModeSheet = false
          SyncManager.cancelSyncMode()
        })

      Text('合并：双向合并歌单；覆盖：单方向整表替换。覆盖操作不可恢复，请谨慎选择。')
        .fontSize(10)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    }
    .width('100%')
  }
}
