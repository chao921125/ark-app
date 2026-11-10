/**
 * 应用入口 — 对齐上游 `src/app.ts` + `src/core/init/*`（启动初始化序列）
 * 初始化顺序：Preferences → FileScanner(沙箱库) → 歌单 → 设置 → 播放内核 → 恢复快照 → 媒体会话
 */
import { AbilityConstant, UIAbility, Want, common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { window } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'

import { PreferencesUtil } from '../persistence/PreferencesUtil'
import { FileScanner } from '../utils/FileScanner'
import { ListPersistence } from '../persistence/ListPersistence'
import { ListStore } from '../store/ListStore'
import { PlayerKernel } from '../player/PlayerKernel'
import { MediaSessionController } from '../player/MediaSessionController'
import { SourceEngine } from '../core/source/SourceEngine'
import { registerBuiltinSources } from '../api/SourceBootstrap'
import { SourceRegistry } from '../api/MusicSource'
import { ThemeController } from '../utils/ThemeController'
import { FloatLyricWindow } from '../lyric/FloatLyricWindow'
import { SyncManager } from '../sync/SyncManager'
import { PlayerFacade } from '../app/PlayerFacade'

const TAG = 'EntryAbility'
const DOMAIN = 0x0001

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate')
    AppStorage.setOrCreate<boolean>('showPlayDetail', false)
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onWindowStageCreate')
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err))
        return
      }
    })

    try {
      const context = this.context as common.UIAbilityContext
      ThemeController.init(context)
      await PreferencesUtil.init(context)
      FileScanner.init(context)
      await ListPersistence.load()
      PlayerKernel.init()
      registerBuiltinSources()
      hilog.info(DOMAIN, TAG, 'after registerBuiltinSources, SourceRegistry.all().length=%{public}d', SourceRegistry.all().length)
      await ListStore.init()
      // 播放域编排层：装配内核依赖 → 恢复音量 → 恢复播放位置 → 接通媒体会话
      await PlayerFacade.init(context)
      // 三期：悬浮窗管理器注入 context（桌面歌词双模式：真悬浮窗优先，失败回落应用内条）
      FloatLyricWindow.init(context)
      // 三期：PC 同步消息层注入 context（gzip 临时文件目录）
      SyncManager.init(context)
      // 自定义音源引擎初始化（prepare 读取 rawfile 沙箱资源，restoreLastSource 恢复上次音源）
      SourceEngine.getInstance().prepare(context)
      try {
        await SourceEngine.getInstance().restoreLastSource()
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'restore last source failed: %{public}s', JSON.stringify(e as BusinessError))
      }
      hilog.info(DOMAIN, TAG, 'init sequence done')
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'init failed: %{public}s', JSON.stringify(err))
    }
  }

  onDestroy(): void {
    void MediaSessionController.destroy()
    void PlayerKernel.release()
    hilog.info(DOMAIN, TAG, 'onDestroy')
  }
}