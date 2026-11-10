/**
 * 音量控制 — 播放域的**运行时**音量状态
 *
 * 职责边界：只管「当前音量是多少、是否静音」。
 * 把音量真正下发到 AVPlayer 由 PlayerKernel 订阅本模块的变更回调完成，
 * 这样音量模块不需要认识 AVPlayer。
 *
 * 【持久化职责已上移】音量作为设置项统一存放在 AppSettings（settings_v1），
 * 由 app/PlayerFacade 负责读取与写回。本模块只保留运行时状态，
 * 避免「两份音量数据源」互相覆盖。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { SystemVolume } from './SystemVolume'
import { MIN_VOLUME, MAX_VOLUME, DEFAULT_VOLUME } from './VolumeScale'

const TAG: string = 'VolumeController'
const DOMAIN: number = 0x0001

export class VolumeController {
  /** 用户设置的音量（0–100），静音时仍保留这里的值 */
  private volume: number = DEFAULT_VOLUME
  private muted: boolean = false
  /** 静音前记住的音量，取消静音时恢复 */
  private lastVolume: number = DEFAULT_VOLUME
  /** 音量变化回调（由 PlayerKernel 订阅，用于下发到 AVPlayer） */
  private listener: ((effectiveVolume: number) => void) | null = null
  /** 系统媒体流音量（-1 表示尚未获取到） */
  private systemMusicVolume: number = -1
  /** 系统媒体流是否被系统静音 */
  private systemMuted: boolean = false
  /** 系统媒体音量变化回调 */
  private systemListener: (() => void) | null = null

  /** 用设置项里的音量初始化运行时状态（启动时调用一次） */
  init(initialVolume: number): void {
    this.volume = VolumeController.clamp(initialVolume)
    this.lastVolume = this.volume
    this.notify()
  }

  /** 当前用户音量（0–100），静音时返回 0 */
  get(): number {
    return this.muted ? MIN_VOLUME : this.volume
  }

  /** 用户设置的音量（不含静音影响） */
  getUserVolume(): number {
    return this.volume
  }

  isMuted(): boolean {
    return this.muted
  }

  /** 设置音量：越界自动钳制；设为非 0 自动取消静音 */
  set(v: number): void {
    const clamped: number = VolumeController.clamp(v)
    if (clamped === this.volume && !this.muted) {
      return
    }
    this.volume = clamped
    if (clamped > 0) {
      this.muted = false
    }
    this.lastVolume = clamped
    this.notify()
  }

  /** 静音 / 取消静音 */
  toggleMute(): void {
    if (this.muted) {
      this.muted = false
      // 之前被静音到 0 时恢复到最近一次设置过的音量
      if (this.volume <= MIN_VOLUME) {
        this.volume = this.lastVolume > MIN_VOLUME ? this.lastVolume : DEFAULT_VOLUME
      }
    } else {
      if (this.volume > MIN_VOLUME) {
        this.lastVolume = this.volume
      }
      this.muted = true
    }
    this.notify()
  }

  /** 订阅音量变化（返回的是**实际输出音量**，静音时为 0） */
  onChange(listener: ((effectiveVolume: number) => void) | null): void {
    this.listener = listener
  }

  /**
   * 监听系统媒体流音量。
   *
   * 应用内音量是**应用级增益**，系统媒体流音量叠加在其上；因此用户在通知面板把
   * 系统媒体音量调到 0 时，本应用实际上也没有声音。本方法把该状态同步进来，
   * 供界面提示「系统已静音」，避免用户误以为应用故障。
   */
  async observeSystemVolume(): Promise<void> {
    const system: SystemVolume = SystemVolume.getInstance()
    system.observe((volume: number, _maxVolume: number, muted: boolean) => {
      this.systemMusicVolume = volume
      this.systemMuted = muted
      const cb: (() => void) | null = this.systemListener
      if (cb !== null) {
        cb()
      }
    })
    const current: number = system.getMusicVolume()
    if (current >= 0) {
      this.systemMusicVolume = current
    }
    system.getMusicMaxVolume()
    this.systemMuted = system.isMusicMuted()
  }

  /** 系统媒体流是否处于静音（用户在通知面板静音）。未知时返回 false */
  isSystemMuted(): boolean {
    return this.systemMuted
  }

  /** 当前系统媒体流音量；未知时返回 -1 */
  getSystemMusicVolume(): number {
    return this.systemMusicVolume
  }

  /** 订阅系统媒体音量变化 */
  onSystemChange(listener: (() => void) | null): void {
    this.systemListener = listener
  }

  private notify(): void {
    const listener = this.listener
    if (listener != null) {
      listener(this.get())
    }
  }

  /** 钳制到 [0, 100] */
  private static clamp(v: number): number {
    if (isNaN(v)) {
      return DEFAULT_VOLUME
    }
    return Math.min(Math.max(Math.round(v), MIN_VOLUME), MAX_VOLUME)
  }
}
