/**
 * 系统媒体音量桥接 —— 只读地获取系统媒体流音量，并监听其变化
 *
 * 【为什么需要这一层】
 * 应用内音量（VolumeController）是**应用级增益**：AVPlayer.setVolume 设定的增益之上，
 * 还会叠加系统媒体流音量。因此通知面板/控制中心的音量条其实**已经在**控制本应用的声音。
 * 但用户看不到这层关系——把系统媒体音量调到 0 之后，应用内的音量条仍显示有音量，
 * 用户会以为应用坏了。本模块把系统侧的静音状态同步给应用，用于在界面上给出提示。
 *
 * 【平台能力边界（依据 SDK 类型定义核实，非推测）】
 *  - AVSession **没有** setVolume 事件：'setVolume' 只出现在投播用的
 *    AVCastControlCommandType 中，普通应用的媒体面板不会下发该命令；
 *  - audio.setVolume(AudioVolumeType, v) 需要 ohos.permission.ACCESS_NOTIFICATION_POLICY
 *    （用户授权），普通应用不应为此向用户索要通知策略权限；
 *  - setAppVolumePercentage（API 19+，免权限）只对渲染器处于 APP_INDIVIDUAL 模式时生效，
 *    而 AVPlayer 未开放设置渲染器 volumeMode 的接口，用了也不确定能否生效；
 *  - 因此本模块只做**只读**（getVolumeByStream / isSystemMutedForStream）与
 *    **监听**（streamVolumeChange），三者均不需要任何权限。
 *
 * 【所用 API】audio.getAudioManager().getVolumeManager() → AudioVolumeManager（API 20+ 正式接口）：
 *   getVolumeByStream / getMaxVolumeByStream / isSystemMutedForStream /
 *   on('streamVolumeChange', streamUsage, cb)
 *   工程 compatibleSdkVersion = 6.0.0(20)，满足 API 20 要求。
 */
import { audio } from '@kit.AudioKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG: string = 'SystemVolume'
const DOMAIN: number = 0x0001

/** 本应用的音频流用途：音乐 */
const MUSIC_USAGE: audio.StreamUsage = audio.StreamUsage.STREAM_USAGE_MUSIC

/** 系统媒体音量变化回调：当前音量、音量上限、是否被系统静音 */
export type MusicVolumeListener = (volume: number, maxVolume: number, muted: boolean) => void

export class SystemVolume {
  private static instance: SystemVolume | null = null

  static getInstance(): SystemVolume {
    if (SystemVolume.instance === null) {
      SystemVolume.instance = new SystemVolume()
    }
    return SystemVolume.instance
  }

  private manager?: audio.AudioVolumeManager
  private listener?: MusicVolumeListener
  private subscribed: boolean = false
  /** 音量上限缓存：streamVolumeChange 事件只带当前值，不带上限 */
  private maxVolume: number = -1

  private getManager(): audio.AudioVolumeManager | undefined {
    if (this.manager === undefined) {
      try {
        // AudioVolumeManager 由 AudioManager 提供（getVolumeManager 是 AudioManager 的方法）
        this.manager = audio.getAudioManager().getVolumeManager()
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'getVolumeManager failed: %{public}s', JSON.stringify(e))
      }
    }
    return this.manager
  }

  /** 当前系统媒体流音量；不可用时返回 -1 */
  getMusicVolume(): number {
    const manager: audio.AudioVolumeManager | undefined = this.getManager()
    if (manager === undefined) {
      return -1
    }
    try {
      return manager.getVolumeByStream(MUSIC_USAGE)
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getVolumeByStream failed: %{public}s', JSON.stringify(e))
      return -1
    }
  }

  /** 系统媒体流音量的上限；不可用时返回 -1 */
  getMusicMaxVolume(): number {
    const manager: audio.AudioVolumeManager | undefined = this.getManager()
    if (manager === undefined) {
      return -1
    }
    try {
      const value: number = manager.getMaxVolumeByStream(MUSIC_USAGE)
      this.maxVolume = value
      return value
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'getMaxVolumeByStream failed: %{public}s', JSON.stringify(e))
      return -1
    }
  }

  /** 系统媒体流是否被系统静音（用户在通知面板/控制中心静音）。不可用时返回 false */
  isMusicMuted(): boolean {
    const manager: audio.AudioVolumeManager | undefined = this.getManager()
    if (manager === undefined) {
      return false
    }
    try {
      return manager.isSystemMutedForStream(MUSIC_USAGE)
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'isSystemMutedForStream failed: %{public}s', JSON.stringify(e))
      return false
    }
  }

  /**
   * 订阅系统媒体音量变化（只关心音乐流，忽略铃声/闹钟等其它流）。
   * 重复调用只会注册一次。
   */
  observe(listener: MusicVolumeListener): void {
    this.listener = listener
    if (this.subscribed) {
      return
    }
    const manager: audio.AudioVolumeManager | undefined = this.getManager()
    if (manager === undefined) {
      return
    }
    try {
      manager.on('streamVolumeChange', MUSIC_USAGE, (event: audio.StreamVolumeEvent) => {
        const cb: MusicVolumeListener | undefined = this.listener
        if (cb !== undefined) {
          cb(event.volume, this.maxVolume, this.isMusicMuted())
        }
      })
      this.subscribed = true
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'subscribe streamVolumeChange failed: %{public}s', JSON.stringify(e))
    }
  }

  /** 取消订阅 */
  release(): void {
    const manager: audio.AudioVolumeManager | undefined = this.manager
    if (manager !== undefined && this.subscribed) {
      try {
        manager.off('streamVolumeChange')
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'off streamVolumeChange failed: %{public}s', JSON.stringify(e))
      }
    }
    this.subscribed = false
    this.listener = undefined
  }
}
