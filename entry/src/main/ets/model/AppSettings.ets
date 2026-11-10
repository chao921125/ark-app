/**
 * 应用设置模型 — 对齐上游 `src/config/defaultSetting.ts`（MVP 子集 + 本项目扩展）
 *
 * 分区归属参考上游 lx-music-mobile：
 *   basic 基本设置 / player 播放设置 / lyric 歌词 / list 列表 / search 搜索 / sync 同步
 */
import { MIN_VOLUME, MAX_VOLUME, DEFAULT_VOLUME } from '../core/volume/VolumeScale'

export type PlayMode = 'listLoop' | 'listRandom' | 'singleLoop'
export type ThemeMode = 'auto' | 'light' | 'dark'
/** 在线播放音质（对齐上游 playerSetting.playQuality） */
export type PlayQuality = '128k' | '320k' | 'flac' | 'flac24bit'
/** 添加歌曲到列表时的位置（对齐上游 list.addMusicLocationType） */
export type AddMusicLocationType = 'top' | 'bottom'

/** 音质降级链：请求质量不可用时依序向下（flac24bit→flac→320k→128k） */
export const QUALITY_LADDER: PlayQuality[] = ['flac24bit', 'flac', '320k', '128k']

/** 所有可用音源 ID（内置 + 自定义） */
export const ALL_SOURCE_IDS: string[] = ['custom', 'kw', 'wy', 'kg', 'tx', 'mg']

export function isPlayQuality(v: string): boolean {
  return v == '128k' || v == '320k' || v == 'flac' || v == 'flac24bit'
}

export function isThemeMode(v: string): boolean {
  return v == 'auto' || v == 'light' || v == 'dark'
}

export function isValidSourceId(v: string): boolean {
  return ALL_SOURCE_IDS.includes(v)
}

export function isAddMusicLocationType(v: string): boolean {
  return v == 'top' || v == 'bottom'
}

export interface AppSettings {
  // ---- 基本设置 ----
  /** 主题：跟随系统 / 浅色 / 深色 */
  themeMode: ThemeMode
  /** 启动后自动播放音乐 */
  startupAutoPlay: boolean
  // ---- 播放设置 ----
  /** 播放模式：列表循环 / 列表随机 / 单曲循环（对齐上游 player.togglePlayMethod） */
  playMode: PlayMode
  /** 在线播放音质：128k / 320k / flac / flac24bit（对齐上游 player.playQuality） */
  playQuality: PlayQuality
  /** 音量 0–100（对齐上游 player.volume） */
  volume: number
  /** 启动时恢复上次播放进度 */
  restorePlayProgress: boolean
  /** 其他应用播放声音时自动暂停本应用（对齐上游 player.isHandleAudioFocus） */
  handleAudioFocus: boolean
  /** 通知栏显示专辑封面（对齐上游 player.isShowNotificationImage） */
  showNotificationImage: boolean
  /** 随机模式下自动清空已播放列表（对齐上游 player.isAutoCleanPlayedList） */
  autoCleanPlayedList: boolean
  // ---- 歌词设置 ----
  /** 歌词字号（vp） */
  lyricFontSize: number
  /** 歌词行间距（vp） */
  lyricLineGap: number
  /** 悬浮歌词（应用内可拖动歌词条） */
  showFloatLyric: boolean
  // ---- 列表设置 ----
  /** 列表显示歌曲时长（对齐上游 list.isShowInterval） */
  showInterval: boolean
  /** 列表显示歌曲专辑名（对齐上游 list.isShowAlbumName） */
  showAlbumName: boolean
  /** 添加歌曲到列表时的位置（对齐上游 list.addMusicLocationType） */
  addMusicLocationType: AddMusicLocationType
  // ---- 搜索设置 ----
  /** 显示历史搜索记录（对齐上游 search.isShowHistorySearch） */
  showHistorySearch: boolean
  /** 显示热门搜索（对齐上游 search.isShowHotSearch） */
  showHotSearch: boolean
  // ---- 其它 ----
  /** 退出前二次确认 */
  exitConfirmation: boolean
  /** 音源优先级：custom(自定义脚本) > kw > wy > kg > tx > mg */
  /**
   * 音源检索顺序（跨源取播放链接/歌词时按此顺序尝试）。
   * 设置页已不再提供调整入口（BasicSection 的「音源优先级」分区已移除），
   * 这里保留为固定顺序，仍可随备份/恢复一起迁移。
   */
  sourcePriority: string[]
}

export const DEFAULT_SETTINGS: AppSettings = {
  // 基本设置
  themeMode: 'auto',
  startupAutoPlay: false,
  // 播放设置
  playMode: 'listLoop',
  playQuality: '128k',
  volume: DEFAULT_VOLUME,
  restorePlayProgress: false,
  handleAudioFocus: true,
  showNotificationImage: true,
  autoCleanPlayedList: false,
  // 歌词设置
  lyricFontSize: 16,
  lyricLineGap: 18,
  showFloatLyric: false,
  // 列表设置
  showInterval: true,
  showAlbumName: false,
  addMusicLocationType: 'top',
  // 搜索设置
  showHistorySearch: false,
  showHotSearch: false,
  // 其它
  exitConfirmation: false,
  sourcePriority: ['custom', 'kw', 'wy', 'kg', 'tx', 'mg']
}

/** 音量钳制（0–100） */
export function clampVolume(v: number): number {
  if (isNaN(v)) {
    return DEFAULT_VOLUME
  }
  return Math.min(Math.max(Math.round(v), MIN_VOLUME), MAX_VOLUME)
}

/**
 * 复制一份设置对象（浅拷贝，字段都是基本类型）。
 * 设置项较多时用「拷贝 → 改字段 → applySettings」的写法，避免手写字段列表时漏字段。
 */
export function cloneSettings(base: AppSettings): AppSettings {
  return {
    themeMode: base.themeMode,
    startupAutoPlay: base.startupAutoPlay,
    playMode: base.playMode,
    playQuality: base.playQuality,
    volume: base.volume,
    restorePlayProgress: base.restorePlayProgress,
    handleAudioFocus: base.handleAudioFocus,
    showNotificationImage: base.showNotificationImage,
    autoCleanPlayedList: base.autoCleanPlayedList,
    lyricFontSize: base.lyricFontSize,
    lyricLineGap: base.lyricLineGap,
    showFloatLyric: base.showFloatLyric,
    showInterval: base.showInterval,
    showAlbumName: base.showAlbumName,
    addMusicLocationType: base.addMusicLocationType,
    showHistorySearch: base.showHistorySearch,
    showHotSearch: base.showHotSearch,
    exitConfirmation: base.exitConfirmation,
    sourcePriority: base.sourcePriority.slice()
  }
}
