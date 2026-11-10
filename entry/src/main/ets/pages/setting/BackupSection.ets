/**
 * 备份与恢复分区 — 对齐上游 `Setting/settings/Backup`
 *
 * 支持导出/导入：设置数据、歌单数据。
 * 导出用 DocumentViewPicker.save() 选保存位置，导入用 DocumentViewPicker.select() 选文件。
 */
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { AppSettings, DEFAULT_SETTINGS } from '../../model/AppSettings'
import { ListStore } from '../../store/ListStore'
import { SettingPersistence } from '../../persistence/SettingPersistence'
import { ListPersistence } from '../../persistence/ListPersistence'
import { SongList } from '../../model/SongList'
import { FileScanner } from '../../utils/FileScanner'
import { SettingSectionTitle, SettingActionRow, SettingDivider, SettingHint } from '../../components/setting/SettingWidgets'

/** 备份文件格式版本，便于后续扩展 */
const BACKUP_VERSION: number = 1

interface SettingsBackup {
  type: 'settings'
  version: number
  settings: AppSettings
}

interface ListsBackup {
  type: 'lists'
  version: number
  lists: SongList[]
}

@Component
export struct BackupSection {
  @State busy: boolean = false

  private async exportSettings(): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    try {
      const context = getContext(this) as common.UIAbilityContext
      const name = `ccn-music-settings-${Date.now()}.json`
      const uri = await FileScanner.pickSaveTarget(context, name)
      if (uri.length == 0) {
        return
      }
      const backup: SettingsBackup = {
        type: 'settings',
        version: BACKUP_VERSION,
        settings: ListStore.getSettings()
      }
      await FileScanner.writeTextToUri(uri, JSON.stringify(backup, null, 2))
      promptAction.showToast({ message: '设置已导出', duration: 2000 })
    } catch (e) {
      promptAction.showToast({ message: `导出失败：${(e as Error).message ?? '未知错误'}`, duration: 3000 })
    } finally {
      this.busy = false
    }
  }

  private async importSettings(): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    try {
      const context = getContext(this) as common.UIAbilityContext
      const uri = await FileScanner.pickJsonFile(context)
      if (uri.length == 0) {
        return
      }
      const text = await FileScanner.readTextFromUri(uri)
      const backup = JSON.parse(text) as SettingsBackup
      if (backup.type != 'settings' || backup.settings == undefined) {
        promptAction.showToast({ message: '文件格式不正确', duration: 2500 })
        return
      }
      // 逐字段合并，缺失的字段回落默认值
      const merged: AppSettings = {
        themeMode: backup.settings.themeMode ?? DEFAULT_SETTINGS.themeMode,
        startupAutoPlay: backup.settings.startupAutoPlay ?? DEFAULT_SETTINGS.startupAutoPlay,
        playMode: backup.settings.playMode ?? DEFAULT_SETTINGS.playMode,
        playQuality: backup.settings.playQuality ?? DEFAULT_SETTINGS.playQuality,
        volume: backup.settings.volume ?? DEFAULT_SETTINGS.volume,
        restorePlayProgress: backup.settings.restorePlayProgress ?? DEFAULT_SETTINGS.restorePlayProgress,
        handleAudioFocus: backup.settings.handleAudioFocus ?? DEFAULT_SETTINGS.handleAudioFocus,
        showNotificationImage: backup.settings.showNotificationImage ?? DEFAULT_SETTINGS.showNotificationImage,
        autoCleanPlayedList: backup.settings.autoCleanPlayedList ?? DEFAULT_SETTINGS.autoCleanPlayedList,
        lyricFontSize: backup.settings.lyricFontSize ?? DEFAULT_SETTINGS.lyricFontSize,
        lyricLineGap: backup.settings.lyricLineGap ?? DEFAULT_SETTINGS.lyricLineGap,
        showFloatLyric: backup.settings.showFloatLyric ?? DEFAULT_SETTINGS.showFloatLyric,
        showInterval: backup.settings.showInterval ?? DEFAULT_SETTINGS.showInterval,
        showAlbumName: backup.settings.showAlbumName ?? DEFAULT_SETTINGS.showAlbumName,
        addMusicLocationType: backup.settings.addMusicLocationType ?? DEFAULT_SETTINGS.addMusicLocationType,
        showHistorySearch: backup.settings.showHistorySearch ?? DEFAULT_SETTINGS.showHistorySearch,
        showHotSearch: backup.settings.showHotSearch ?? DEFAULT_SETTINGS.showHotSearch,
        exitConfirmation: backup.settings.exitConfirmation ?? DEFAULT_SETTINGS.exitConfirmation,
        sourcePriority: Array.isArray(backup.settings.sourcePriority) && backup.settings.sourcePriority.length > 0
          ? backup.settings.sourcePriority : DEFAULT_SETTINGS.sourcePriority
      }
      ListStore.applySettings(merged)
      await SettingPersistence.save(merged)
      promptAction.showToast({ message: '设置已导入', duration: 2000 })
    } catch (e) {
      promptAction.showToast({ message: `导入失败：${(e as Error).message ?? '文件解析失败'}`, duration: 3000 })
    } finally {
      this.busy = false
    }
  }

  private async exportLists(): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    try {
      const context = getContext(this) as common.UIAbilityContext
      const name = `ccn-music-lists-${Date.now()}.json`
      const uri = await FileScanner.pickSaveTarget(context, name)
      if (uri.length == 0) {
        return
      }
      const backup: ListsBackup = {
        type: 'lists',
        version: BACKUP_VERSION,
        lists: ListPersistence.getLists().map(l => {
          const copy: SongList = {
            id: l.id,
            name: l.name,
            list: l.list.slice(),
            positionUpdateTime: l.positionUpdateTime
          }
          return copy
        })
      }
      await FileScanner.writeTextToUri(uri, JSON.stringify(backup, null, 2))
      promptAction.showToast({ message: '歌单已导出', duration: 2000 })
    } catch (e) {
      promptAction.showToast({ message: `导出失败：${(e as Error).message ?? '未知错误'}`, duration: 3000 })
    } finally {
      this.busy = false
    }
  }

  private async importLists(): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    try {
      const context = getContext(this) as common.UIAbilityContext
      const uri = await FileScanner.pickJsonFile(context)
      if (uri.length == 0) {
        return
      }
      const text = await FileScanner.readTextFromUri(uri)
      const backup = JSON.parse(text) as ListsBackup
      if (backup.type != 'lists' || !Array.isArray(backup.lists)) {
        promptAction.showToast({ message: '文件格式不正确', duration: 2500 })
        return
      }
      // 覆盖式导入：内置歌单保留，用户歌单整体替换
      const def = ListPersistence.getList('default')
      const local = ListPersistence.getList('local_music')
      const userLists: SongList[] = []
      for (let i = 0; i < backup.lists.length; i++) {
        const l = backup.lists[i]
        if (l.id == 'default' || l.id == 'local_music') {
          continue
        }
        userLists.push(l)
      }
      const defSongs = def != undefined ? def.list.slice() : []
      const localSongs = local != undefined ? local.list.slice() : []
      await ListPersistence.overwriteSyncData(defSongs, userLists)
      promptAction.showToast({ message: '歌单已导入', duration: 2000 })
    } catch (e) {
      promptAction.showToast({ message: `导入失败：${(e as Error).message ?? '文件解析失败'}`, duration: 3000 })
    } finally {
      this.busy = false
    }
  }

  build() {
    Column({ space: 12 }) {
      SettingSectionTitle('备份与恢复')

      Column() {
        SettingActionRow('导出设置', '把当前所有设置项导出为 JSON 文件', this.busy ? '处理中…' : '导出', () => {
          void this.exportSettings()
        })
        SettingDivider()
        SettingActionRow('导入设置', '从 JSON 文件恢复设置项（缺失字段取默认值）', this.busy ? '处理中…' : '导入', () => {
          void this.importSettings()
        })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      Column() {
        SettingActionRow('导出歌单', '把当前所有歌单（含喜欢的音乐、本地音乐）导出为 JSON 文件',
          this.busy ? '处理中…' : '导出', () => {
            void this.exportLists()
          })
        SettingDivider()
        SettingActionRow('导入歌单', '从 JSON 文件恢复歌单（覆盖式，内置歌单保留）', this.busy ? '处理中…' : '导入', () => {
          void this.importLists()
        })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      SettingHint('导入歌单为覆盖式操作，用户歌单会被整体替换，操作前建议先导出备份。')
    }
    .width('100%')
  }
}
