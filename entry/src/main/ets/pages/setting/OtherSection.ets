/**
 * 其它分区 — 对齐上游 `Setting/settings/Other`
 *
 * 含：缓存管理（歌词 / 封面）、清除数据。
 */
import { fileIo as fs } from '@kit.CoreFileKit'

import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { PreferencesUtil } from '../../persistence/PreferencesUtil'
import { ListPersistence } from '../../persistence/ListPersistence'
import { ListStore } from '../../store/ListStore'
import { DEFAULT_SETTINGS } from '../../model/AppSettings'
import { SettingPersistence } from '../../persistence/SettingPersistence'
import { FileScanner } from '../../utils/FileScanner'
import { SettingSectionTitle, SettingActionRow, SettingDivider, SettingHint } from '../../components/setting/SettingWidgets'

const TAG: string = 'OtherSection'
const DOMAIN: number = 0x0001

@Component
export struct OtherSection {
  @State lyricCacheCount: number = 0
  @State coverCacheCount: number = 0
  @State cacheSizeText: string = '计算中…'

  aboutToAppear(): void {
    this.refreshCacheStat()
  }

  /** 统计沙箱 library/ 下的歌词与封面缓存（音频属于用户数据，不计入缓存） */
  private refreshCacheStat(): void {
    let lyricCount: number = 0
    let coverCount: number = 0
    let totalSize: number = 0
    try {
      const dir: string = FileScanner.getLibraryDir()
      if (fs.accessSync(dir)) {
        const names: string[] = fs.listFileSync(dir)
        for (let i = 0; i < names.length; i++) {
          const name: string = names[i]
          if (name.endsWith('.lrc')) {
            lyricCount++
          } else if (name.endsWith('_cover.jpg')) {
            coverCount++
          } else {
            continue
          }
          try {
            totalSize += fs.statSync(`${dir}/${name}`).size
          } catch (ignored) {
            // 单个文件统计失败不影响整体
          }
        }
      }
    } catch (e) {
      // 目录不存在等异常情况
    }
    this.lyricCacheCount = lyricCount
    this.coverCacheCount = coverCount
    const kb: number = Math.round(totalSize / 1024)
    this.cacheSizeText = kb > 1024 ? `${(kb / 1024).toFixed(1)} MB` : `${kb} KB`
  }

  /** 清理歌词与封面缓存（不动音频文件） */
  private clearCache(): void {
    promptAction.showDialog({
      title: '清理缓存',
      message: `将删除 ${this.lyricCacheCount} 个歌词文件与 ${this.coverCacheCount} 个封面文件，音频文件不受影响。确定继续吗？`,
      buttons: [
        { text: '取消', color: $r('app.color.text_secondary') },
        { text: '清理', color: '#E05454' }
      ]
    }).then((result: promptAction.ShowDialogSuccessResponse) => {
      // 【必须判断 result.index】用户点「取消」时不能执行清理
      if (result.index != 1) {
        return
      }
      let removed: number = 0
      try {
        const dir: string = FileScanner.getLibraryDir()
        if (fs.accessSync(dir)) {
          const names: string[] = fs.listFileSync(dir)
          for (let i = 0; i < names.length; i++) {
            const name: string = names[i]
            if (!name.endsWith('.lrc') && !name.endsWith('_cover.jpg')) {
              continue
            }
            try {
              fs.unlinkSync(`${dir}/${name}`)
              removed++
            } catch (ignored) {
              // 单个文件删除失败不影响整体
            }
          }
        }
      } catch (e) {
        // 清理失败要让用户知道，否则只看到「已清理 0 个」却不知为何没清掉
        hilog.error(DOMAIN, TAG, 'clear cache failed: %{public}s', JSON.stringify(e))
        this.refreshCacheStat()
        promptAction.showToast({ message: '清理失败，请重试', duration: 1800 })
        return
      }
      this.refreshCacheStat()
      promptAction.showToast({ message: `已清理 ${removed} 个缓存文件`, duration: 2000 })
    }).catch(() => {
      // 对话框取消
    })
  }

  /** 清除全部数据（设置 + 歌单 + 偏好） */
  private async clearAllData(): Promise<void> {
    promptAction.showDialog({
      title: '清除数据',
      message: '将清除全部设置、歌单与偏好数据，且不可恢复。确定继续吗？',
      buttons: [
        { text: '取消', color: $r('app.color.text_secondary') },
        { text: '清除', color: '#E05454' }
      ]
    }).then(async (result: promptAction.ShowDialogSuccessResponse) => {
      // 【必须判断 result.index】用户点「取消」时不能清除数据
      if (result.index != 1) {
        return
      }
      try {
        await ListPersistence.clearList('default')
        await ListPersistence.clearList('local_music')
        await PreferencesUtil.clear()
        ListStore.applySettings(DEFAULT_SETTINGS)
        await SettingPersistence.save(DEFAULT_SETTINGS)
        AppStorage.setOrCreate<number>('lyricFontSize', DEFAULT_SETTINGS.lyricFontSize)
        AppStorage.setOrCreate<number>('lyricLineGap', DEFAULT_SETTINGS.lyricLineGap)
        await ListStore.reload()
        // 收藏/队列状态归零：递增版本号刷新各页爱心与队列弹层
        AppStorage.setOrCreate<number>('likeListRev', (AppStorage.get<number>('likeListRev') ?? 0) + 1)
        promptAction.showToast({ message: '数据已清除', duration: 2000 })
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'clear all data failed: %{public}s', JSON.stringify(e))
        promptAction.showToast({ message: '清除失败，请重试', duration: 1800 })
      }
    }).catch(() => {
      // 对话框被系统取消（promise reject），不做任何事
    })
  }

  build() {
    Column({ space: 12 }) {
      SettingSectionTitle('缓存管理')

      Column() {
        SettingActionRow('缓存占用', `歌词 ${this.lyricCacheCount} 个 · 封面 ${this.coverCacheCount} 个`, this.cacheSizeText, () => {
          this.refreshCacheStat()
        })
        SettingDivider()
        SettingActionRow('清理缓存', '删除歌词与封面文件，音频文件不受影响', '清理', () => {
          this.clearCache()
        })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      SettingSectionTitle('数据')

      Column() {
        SettingActionRow('清除全部数据', '清除设置、歌单与偏好数据，不可恢复', '清除', () => {
          void this.clearAllData()
        })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      SettingHint('上游还提供「不喜欢的歌曲」规则、错误日志查看与自定义源日志，\n本项目尚未实现对应能力，故此处不提供。')
    }
    .width('100%')
  }
}
