/**
 * 设置持久化 — 对齐上游 `src/config/setting.ts`（JSON 序列化存储）
 */
import { PreferencesUtil } from './PreferencesUtil'
import {
  AppSettings,
  DEFAULT_SETTINGS,
  PlayMode,
  PlayQuality,
  ThemeMode,
  AddMusicLocationType,
  isPlayQuality,
  isThemeMode,
  isAddMusicLocationType,
  clampVolume,
  ALL_SOURCE_IDS
} from '../model/AppSettings'

const KEY_SETTINGS = 'settings_v1'

class SettingPersistenceImpl {
  async load(): Promise<AppSettings> {
    let json = ''
    try {
      json = await PreferencesUtil.getString(KEY_SETTINGS)
    } catch (e) {
      // ignore, fallback to defaults
    }
    if (json.length == 0) {
      return DEFAULT_SETTINGS
    }
    try {
      const saved = JSON.parse(json) as Partial<AppSettings>
      const savedQuality = saved.playQuality
      const playQuality: PlayQuality =
        savedQuality != undefined && typeof savedQuality == 'string' && isPlayQuality(savedQuality)
          ? savedQuality as PlayQuality : DEFAULT_SETTINGS.playQuality
      const savedPriority = saved.sourcePriority
      const sourcePriority: string[] = (Array.isArray(savedPriority) && savedPriority.every(v => ALL_SOURCE_IDS.includes(v)))
        ? savedPriority : DEFAULT_SETTINGS.sourcePriority
      const savedLocation = saved.addMusicLocationType
      const addMusicLocationType: AddMusicLocationType =
        savedLocation != undefined && typeof savedLocation == 'string' && isAddMusicLocationType(savedLocation)
          ? savedLocation as AddMusicLocationType : DEFAULT_SETTINGS.addMusicLocationType
      // 逐字段合并：旧版本设置里没有的新增字段一律取默认值（向后兼容）
      const merged: AppSettings = {
        // 基本设置
        themeMode: isThemeMode(saved.themeMode ?? '') ? saved.themeMode as ThemeMode : DEFAULT_SETTINGS.themeMode,
        startupAutoPlay: saved.startupAutoPlay ?? DEFAULT_SETTINGS.startupAutoPlay,
        // 播放设置
        playMode: (saved.playMode ?? DEFAULT_SETTINGS.playMode) as PlayMode,
        playQuality: playQuality,
        volume: clampVolume(saved.volume ?? DEFAULT_SETTINGS.volume),
        restorePlayProgress: saved.restorePlayProgress ?? DEFAULT_SETTINGS.restorePlayProgress,
        handleAudioFocus: saved.handleAudioFocus ?? DEFAULT_SETTINGS.handleAudioFocus,
        showNotificationImage: saved.showNotificationImage ?? DEFAULT_SETTINGS.showNotificationImage,
        autoCleanPlayedList: saved.autoCleanPlayedList ?? DEFAULT_SETTINGS.autoCleanPlayedList,
        // 歌词设置
        lyricFontSize: saved.lyricFontSize ?? DEFAULT_SETTINGS.lyricFontSize,
        lyricLineGap: saved.lyricLineGap ?? DEFAULT_SETTINGS.lyricLineGap,
        showFloatLyric: saved.showFloatLyric ?? DEFAULT_SETTINGS.showFloatLyric,
        // 列表设置
        showInterval: saved.showInterval ?? DEFAULT_SETTINGS.showInterval,
        showAlbumName: saved.showAlbumName ?? DEFAULT_SETTINGS.showAlbumName,
        addMusicLocationType: addMusicLocationType,
        // 搜索设置
        showHistorySearch: saved.showHistorySearch ?? DEFAULT_SETTINGS.showHistorySearch,
        showHotSearch: saved.showHotSearch ?? DEFAULT_SETTINGS.showHotSearch,
        // 其它
        exitConfirmation: saved.exitConfirmation ?? DEFAULT_SETTINGS.exitConfirmation,
        sourcePriority: sourcePriority
      }
      return merged
    } catch (e) {
      return DEFAULT_SETTINGS
    }
  }

  async save(settings: AppSettings): Promise<void> {
    await PreferencesUtil.setString(KEY_SETTINGS, JSON.stringify(settings))
  }
}

export const SettingPersistence: SettingPersistenceImpl = new SettingPersistenceImpl()