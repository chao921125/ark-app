/**
 * 媒体会话控制器 — 对齐上游 react-native-track-player（通知栏媒体控制 + 后台播放）
 * 使用 HarmonyOS AVSession + 长时任务（AUDIO_PLAYBACK）实现。
 *
 * 【模块边界】本模块只做「系统媒体通知与后台任务的接线」。
 * 快照持久化由编排层注入的回调完成（不直接依赖 store/），因此不产生循环引用。
 */
import { avSession as AVSessionManager } from '@kit.AVSessionKit'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import { wantAgent } from '@kit.AbilityKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PlayerKernel, PlayerSnapshotListener, PlayerStatus } from './PlayerKernel'
import { MusicInfo } from '../model/MusicInfo'

const TAG = 'MediaSessionCtl'
const DOMAIN = 0x0001
const BUNDLE_NAME = 'cn.ccn.music'
/** 通知栏进度回写节流间隔（毫秒）：太频繁会被系统丢弃，太慢则进度条卡顿 */
const POSITION_SYNC_INTERVAL: number = 1000

/** 由编排层注入的外部能力 */
export interface MediaSessionConfig {
  /** 保存当前播放快照（切歌/暂停时调用） */
  saveSnapshot(): void
}

class MediaSessionControllerImpl implements PlayerSnapshotListener {
  private session?: AVSessionManager.AVSession
  private context?: common.UIAbilityContext
  private bgRunning: boolean = false
  private config?: MediaSessionConfig
  /** 通知栏是否显示专辑封面（对齐上游 player.isShowNotificationImage） */
  private showNotificationImage: boolean = true
  /** 上次回写通知栏进度的时刻，用于节流 */
  private lastPositionSync: number = 0

  async init(context: common.UIAbilityContext, config: MediaSessionConfig): Promise<void> {
    this.context = context
    this.config = config
    try {
      this.session = await AVSessionManager.createAVSession(context, 'lx_music_session', 'audio')
      this.registerCommands()
      PlayerKernel.setListener(this)
      await this.session.activate()
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'init avsession failed: %{public}s', JSON.stringify(err))
    }
  }

  private registerCommands(): void {
    const session = this.session
    if (session == undefined) {
      return
    }
    session.on('play', () => {
      void PlayerKernel.toggle()
    })
    session.on('pause', () => {
      void PlayerKernel.toggle()
    })
    session.on('playNext', () => {
      void PlayerKernel.skipNext()
    })
    session.on('playPrevious', () => {
      void PlayerKernel.skipPrev()
    })
    session.on('seek', (time: number) => {
      void PlayerKernel.seek(time / 1000)
    })
    session.on('stop', () => {
      void PlayerKernel.pause()
    })
  }

  /** 设置通知栏是否显示专辑封面 */
  setShowNotificationImage(on: boolean): void {
    this.showNotificationImage = on
  }

  onTrackChanged(music: MusicInfo | undefined, _index: number): void {
    void this.updateMetadata(music)
    // 切歌即保存快照（位置为 0 起点），供下次启动恢复
    this.saveSnapshot()
  }

  onDurationChanged(sec: number): void {
    // 时长就绪后补写媒体通知的 duration
    const session = this.session
    if (session == undefined || sec <= 0) {
      return
    }
    try {
      const playbackState: AVSessionManager.AVPlaybackState = {
        state: AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY,
        position: {
          elapsedTime: Math.floor(AppStorage.get<number>('progressTime') ?? 0) * 1000,
          updateTime: Date.now()
        },
        duration: Math.floor(sec * 1000)
      }
      void session.setAVPlaybackState(playbackState)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'onDurationChanged failed: %{public}s', JSON.stringify(e))
    }
  }

  onStatusChanged(status: PlayerStatus): void {
    void this.updatePlaybackState(status)
    if (status == 'playing') {
      void this.startBgTask()
    } else if (status == 'paused' || status == 'idle') {
      void this.stopBgTask()
      // 暂停时保存播放进度快照（设置项"恢复上次播放进度"的数据来源）
      this.saveSnapshot()
    }
  }

  /**
   * 播放进度回调：节流后回写通知栏进度条，
   * 否则通知栏的进度条会停在 0（此前只在时长就绪时写过一次 position）。
   */
  onProgressChanged(_sec: number): void {
    const now: number = Date.now()
    if (now - this.lastPositionSync < POSITION_SYNC_INTERVAL) {
      return
    }
    this.lastPositionSync = now
    void this.updatePlaybackState(PlayerKernel.getStatus())
  }

  private saveSnapshot(): void {
    const config = this.config
    if (config == undefined) {
      return
    }
    try {
      config.saveSnapshot()
    } catch (ignored) {
      // 快照失败不影响播放
    }
  }

  private async updateMetadata(music: MusicInfo | undefined): Promise<void> {
    const session = this.session
    if (session == undefined || music == undefined) {
      return
    }
    try {
      const meta: AVSessionManager.AVMetadata = {
        assetId: music.id,
        title: music.name,
        artist: music.singer
      }
      // 本 SDK 经 mediaImage 携带封面（支持沙箱内路径字符串；本地导入时由元数据落盘）
      const picPath = music.meta.picUrl
      if (this.showNotificationImage && picPath != undefined && picPath.length > 0) {
        meta.mediaImage = picPath
      }
      await session.setAVMetadata(meta)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'updateMetadata failed: %{public}s', JSON.stringify(e))
    }
  }

  private async updatePlaybackState(status: PlayerStatus): Promise<void> {
    const session = this.session
    if (session == undefined) {
      return
    }
    try {
      const state = status == 'playing'
        ? AVSessionManager.PlaybackState.PLAYBACK_STATE_PLAY
        : (status == 'paused'
          ? AVSessionManager.PlaybackState.PLAYBACK_STATE_PAUSE
          : AVSessionManager.PlaybackState.PLAYBACK_STATE_STOP)
      const playbackState: AVSessionManager.AVPlaybackState = {
        state: state,
        position: {
          elapsedTime: Math.floor(AppStorage.get<number>('progressTime') ?? 0) * 1000,
          updateTime: Date.now()
        }
      }
      await session.setAVPlaybackState(playbackState)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'updatePlaybackState failed: %{public}s', JSON.stringify(e))
    }
  }

  /** 供播放页进度条拖动后刷新媒体通知进度 */
  async syncPlaybackPosition(): Promise<void> {
    this.lastPositionSync = Date.now()
    const status = PlayerKernel.getStatus()
    await this.updatePlaybackState(status)
  }

  private async startBgTask(): Promise<void> {
    if (this.bgRunning || this.context == undefined) {
      return
    }
    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: BUNDLE_NAME,
            abilityName: 'EntryAbility'
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0
      }
      const wantAgentObj = await wantAgent.getWantAgent(wantAgentInfo)
      await backgroundTaskManager.startBackgroundRunning(
        this.context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        wantAgentObj
      )
      this.bgRunning = true
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'startBackgroundRunning failed: %{public}s', JSON.stringify(e))
    }
  }

  private async stopBgTask(): Promise<void> {
    if (!this.bgRunning || this.context == undefined) {
      return
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(this.context)
      this.bgRunning = false
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'stopBackgroundRunning failed: %{public}s', JSON.stringify(e))
    }
  }

  async destroy(): Promise<void> {
    await this.stopBgTask()
    try {
      if (this.session != undefined) {
        await this.session.destroy()
        this.session = undefined
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'destroy session failed: %{public}s', JSON.stringify(e))
    }
  }
}

export const MediaSessionController: MediaSessionControllerImpl = new MediaSessionControllerImpl()
