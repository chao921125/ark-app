/**
 * 播放域编排层 — UI 访问播放能力的**唯一入口**
 *
 * 【为什么需要这一层】
 * 重构前 player/ 与 store/ 互相 import，形成 3 条循环依赖：
 *   ListStore ↔ PlayerKernel、PlayerKernel ↔ PlayerStore、ListStore → … → PlayerStore → ListStore
 * 根因是「谁调用谁」的责任落在了错误的层上。本层把跨层协调集中到一处：
 *
 *   UI → PlayerFacade → { PlayerKernel, PlayerStore, ListStore, SourceResolver, MediaSession }
 *
 * 具体的解耦手法：
 *   1. 设置下发：ListStore 变更 → 通知本层 → 本层推给 PlayerKernel（ListStore 不再认识播放器）
 *   2. 快照时机：切歌/暂停的时机由本层掌握，PlayerStore 只接收参数、不反查内核
 *   3. 音源覆盖：PlayerKernel 通过注入的回调读取 PlayerStore（内核不 import store）
 *
 * 于是 player/ 与 store/ 之间不再有 import 关系，依赖方向全部向下。
 */
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'

import { MusicInfo } from '../model/MusicInfo'
import { AppSettings, PlayMode, PlayQuality, cloneSettings, clampVolume } from '../model/AppSettings'
import { PlayerKernel, PlayerKernelConfig } from '../player/PlayerKernel'
import { MediaSessionController, MediaSessionConfig } from '../player/MediaSessionController'
import { PlayerStore, RestoredTarget } from '../store/PlayerStore'
import { ListStore } from '../store/ListStore'
import { ListPersistence } from '../persistence/ListPersistence'
import { SettingPersistence } from '../persistence/SettingPersistence'
import { SourceResolver } from '../core/source/SourceResolver'

const TAG = 'PlayerFacade'
const DOMAIN = 0x0001

/**
 * 内核配置实现 —— 把「读音源覆盖」与「报错回调」交给播放内核。
 * 用类而非对象字面量：ArkTS 的 arkts-no-untyped-obj-literals 不允许对象字面量承载函数属性。
 */
class KernelConfigImpl implements PlayerKernelConfig {
  private errorHandler: (message: string) => void

  constructor(errorHandler: (message: string) => void) {
    this.errorHandler = errorHandler
  }

  getSourceOverride(musicId: string): Promise<string | undefined> {
    return PlayerStore.getSourceOverride(musicId)
  }

  onError(message: string): void {
    this.errorHandler(message)
  }
}

/** 媒体会话配置实现 —— 切歌/暂停时由媒体会话回调本层保存快照 */
class MediaSessionConfigImpl implements MediaSessionConfig {
  private snapshotSaver: () => void

  constructor(snapshotSaver: () => void) {
    this.snapshotSaver = snapshotSaver
  }

  saveSnapshot(): void {
    this.snapshotSaver()
  }
}

class PlayerFacadeImpl {
  private initialized: boolean = false

  /**
   * 装配播放域：注入内核依赖、恢复音量与播放位置、接通媒体会话。
   * 必须在 ListStore.init() 与 PlayerKernel.init() 之后调用。
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) {
      return
    }
    this.initialized = true

    // 1) 设置变更 → 同步到播放内核与音源解析器（ListStore 不再直接驱动播放器）
    //    用箭头函数包一层，避免把 this 绑定丢失
    ListStore.onChange((settings: AppSettings): void => {
      this.handleSettingsChanged(settings)
    })
    this.handleSettingsChanged(ListStore.getSettings())

    // 2) 内核依赖注入（依赖倒置：内核不 import store）
    //    注：ArkTS 不允许用对象字面量承载函数属性（arkts-no-untyped-obj-literals），
    //    因此这里用类实现，与项目内 SourceRegistry / PlayerKernel 的写法保持一致。
    const config: PlayerKernelConfig = new KernelConfigImpl((message: string): void => {
      this.handleError(message)
    })
    PlayerKernel.configure(config)

    // 3) 恢复上次音量（音量是设置项，持久化在 AppSettings 里）
    await PlayerKernel.restoreVolume(ListStore.getSettings().volume)

    // 4) 恢复上次播放位置（不自动播放，等用户点播放）
    await this.restore()

    // 5) 媒体会话接线（快照保存由本层注入，媒体会话不依赖 store）
    const sessionConfig: MediaSessionConfig = new MediaSessionConfigImpl((): void => {
      void this.saveSnapshot()
    })
    await MediaSessionController.init(context, sessionConfig)
  }

  // ------------------------------------------------------------ 设置 → 内核

  private handleSettingsChanged(settings: AppSettings): void {
    PlayerKernel.setMode(settings.playMode)
    PlayerKernel.setPlayQuality(settings.playQuality)
    PlayerKernel.setAudioFocusEnabled(settings.handleAudioFocus)
    PlayerKernel.setAutoCleanPlayedList(settings.autoCleanPlayedList)
    MediaSessionController.setShowNotificationImage(settings.showNotificationImage)
    SourceResolver.getInstance().setPriority(settings.sourcePriority)
  }

  /** 播放失败提示（内核不直接弹 toast，统一在这里处理） */
  private handleError(message: string): void {
    hilog.warn(DOMAIN, TAG, 'play error: %{public}s', message)
    try {
      promptAction.showToast({ message: message, duration: 2500 })
    } catch (ignored) {
      // 无 UI 上下文时忽略
    }
  }

  // ------------------------------------------------------------ 播放控制

  async toggle(): Promise<void> {
    await PlayerKernel.toggle()
  }

  async pause(): Promise<void> {
    await PlayerKernel.pause()
  }

  async seek(sec: number): Promise<void> {
    await PlayerKernel.seek(sec)
  }

  async skipNext(): Promise<void> {
    await PlayerKernel.skipNext()
  }

  async skipPrev(): Promise<void> {
    await PlayerKernel.skipPrev()
  }

  async playIndex(index: number): Promise<void> {
    await PlayerKernel.playIndex(index)
  }

  /** 从某个歌单的第 index 首开始播放（同时记录快照所属的歌单） */
  async playFromList(listId: string, musics: MusicInfo[], index: number): Promise<void> {
    PlayerStore.setSnapshotListId(listId)
    PlayerKernel.setList(musics, index)
    await PlayerStore.saveSnapshot(listId, index, 0)
  }

  /** 换源播放：用新源的同一首歌替换队列当前位置 */
  async replaceCurrent(music: MusicInfo): Promise<void> {
    await PlayerKernel.replaceCurrent(music)
  }

  /** 记录某首歌的音源覆盖（换源播放持久化） */
  async setSourceOverride(songId: string, sourceId: string): Promise<void> {
    try {
      await PlayerStore.setSourceOverride(songId, sourceId)
    } catch (ignored) {
      // 持久化失败不影响本次播放
    }
  }

  // ------------------------------------------------------------ 播放队列

  getQueue(): MusicInfo[] {
    return PlayerKernel.getList()
  }

  getQueueIndex(): number {
    return PlayerKernel.getIndex()
  }

  /**
   * 按歌曲 id 定位播放：在**真实播放队列**里查找该曲目的位置后播放。
   *
   * 【为什么不用 index】UI 里的列表往往是一份快照（打开时取的），
   * 而真实队列可能已被增删/重排 —— 用过期的 index 定位会播到另一首歌。
   * 按 id 定位则与快照是否过期无关。
   * @returns 是否找到并开始播放
   */
  async playById(musicId: string): Promise<boolean> {
    const queue: MusicInfo[] = PlayerKernel.getList()
    for (let i = 0; i < queue.length; i++) {
      if (queue[i].id == musicId) {
        await PlayerKernel.playIndex(i)
        return true
      }
    }
    return false
  }

  async removeAt(index: number): Promise<void> {
    await PlayerKernel.removeAt(index)
  }

  /** 队列内重排：把 from 位置的曲目移到 to 位置 */
  moveInQueue(from: number, to: number): boolean {
    return PlayerKernel.moveInQueue(from, to)
  }

  /** 清空播放队列并停止播放 */
  async clearQueue(): Promise<void> {
    await PlayerKernel.clearQueue()
  }

  /**
   * 把当前播放队列保存为一个新歌单。
   * @param name 新歌单名称
   * @returns 实际保存的歌曲数（0 表示名称为空或队列为空）
   */
  async saveQueueAsList(name: string): Promise<number> {
    const trimmed: string = name.trim()
    if (trimmed.length === 0) {
      return 0
    }
    const queue: MusicInfo[] = PlayerKernel.getList()
    if (queue.length === 0) {
      return 0
    }
    const list = await ListPersistence.addList(trimmed)
    const added: number = await ListPersistence.addMusics(list.id, queue)
    if (added > 0) {
      // 通知界面刷新（歌单列表 + 当前歌单内容）
      ListPersistence.notifySyncChanged()
    }
    return added
  }

  // ------------------------------------------------------------ 播放模式与音质

  getMode(): PlayMode {
    return PlayerKernel.getMode()
  }

  /** 切换播放模式并持久化（此前在播放详情页切换的模式不会保存，重启后丢失） */
  async setMode(mode: PlayMode): Promise<void> {
    PlayerKernel.setMode(mode)
    const next: AppSettings = cloneSettings(ListStore.getSettings())
    next.playMode = mode
    ListStore.applySettings(next)
    try {
      await SettingPersistence.save(next)
    } catch (ignored) {
      // 持久化失败不影响本次会话
    }
  }

  getPlayQuality(): PlayQuality {
    return (AppStorage.get<string>('playQuality') ?? '128k') as PlayQuality
  }

  async setPlayQuality(quality: PlayQuality): Promise<void> {
    PlayerKernel.setPlayQuality(quality)
    const next: AppSettings = cloneSettings(ListStore.getSettings())
    next.playQuality = quality
    ListStore.applySettings(next)
    try {
      await SettingPersistence.save(next)
    } catch (ignored) {
      // 持久化失败不影响本次会话
    }
  }

  // ------------------------------------------------------------ 音量

  /** 当前音量（0–100，静音时为 0） */
  getVolume(): number {
    return PlayerKernel.getVolume()
  }

  /** 音量落盘防抖计时器：拖动滑块时每帧都会回调，落盘需合并 */
  private volumePersistTimer: number = 0

  /**
   * 设置音量：立即生效（能听到实时反馈），落盘做 600ms 防抖。
   * 音量是设置项，统一存放在 AppSettings（settings_v1），
   * 本层负责协调「运行时音量（VolumeController）」与「持久化设置」两份状态。
   */
  setVolume(v: number): void {
    PlayerKernel.setVolume(v)
    if (this.volumePersistTimer != 0) {
      clearTimeout(this.volumePersistTimer)
      this.volumePersistTimer = 0
    }
    this.volumePersistTimer = setTimeout(() => {
      this.volumePersistTimer = 0
      const next: AppSettings = cloneSettings(ListStore.getSettings())
      next.volume = clampVolume(PlayerKernel.getVolume())
      ListStore.applySettings(next)
    }, 600)
  }

  isMuted(): boolean {
    return PlayerKernel.isMuted()
  }

  toggleMute(): void {
    PlayerKernel.toggleMute()
  }

  // ------------------------------------------------------------ 快照

  /** 保存当前播放快照（切歌 / 暂停时调用） */
  async saveSnapshot(): Promise<void> {
    try {
      await PlayerStore.saveSnapshot(
        PlayerStore.getSnapshotListId(),
        PlayerKernel.getIndex(),
        PlayerKernel.getProgressSec()
      )
    } catch (e) {
      // 快照保存失败只会导致「下次启动恢复不到位置」，不应打断播放，但必须留痕
      hilog.error(DOMAIN, TAG, 'save snapshot failed: %{public}s', JSON.stringify(e))
    }
  }

  /** 恢复上次播放位置（默认不自动播放） */
  async restore(): Promise<void> {
    const settings: AppSettings = ListStore.getSettings()
    const target: RestoredTarget | null = await PlayerStore.restore(settings.restorePlayProgress)
    if (target == null) {
      return
    }
    PlayerKernel.setListWithoutPlay(target.musics, target.index, target.position)
    AppStorage.setOrCreate<number>('playIndex', target.index)
    AppStorage.setOrCreate<number>('progressTime', target.position)
    AppStorage.setOrCreate<string>('currentMusicJson', JSON.stringify(target.music))
    // 启动后自动播放（对齐上游 common.isStartupAutoPlay）
    if (settings.startupAutoPlay) {
      await PlayerKernel.playIndex(target.index)
    }
  }

  /** 拖动进度条后刷新通知栏进度 */
  async syncSessionPosition(): Promise<void> {
    await MediaSessionController.syncPlaybackPosition()
  }
}

export const PlayerFacade: PlayerFacadeImpl = new PlayerFacadeImpl()
