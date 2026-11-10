/**
 * 播放内核 — 移植上游 `src/core/player/player.ts` 状态机行为 + react-native-track-player 播放能力
 * 底层使用 HarmonyOS AVPlayer；全局状态写入 AppStorage（对齐上游 Redux store/player）。
 *
 * 【模块边界】本模块只负责「播放这件事」：
 *   - AVPlayer 生命周期与播放状态机
 *   - 播放队列（委托 core/queue/PlayQueue）
 *   - 音质降级解析
 *   - 播放地址解析（委托 core/source/SourceResolver）
 *   - 音量下发
 *
 * 【依赖规则】本模块**不依赖** store/ 与 api/：
 *   - 音源优先级、单曲音源覆盖由 configure() 注入（依赖倒置）；
 *   - 播放失败提示由配置里的 onError 回调交给上层决定；
 *   - 因此 player/ 与 store/ 之间不存在循环引用。
 */
import { media } from '@kit.MediaKit'
import { audio } from '@kit.AudioKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MusicInfo, MusicInfoMetaOnline, isLocalInfo, toLocalMeta } from '../model/MusicInfo'
import { PlayMode, PlayQuality, QUALITY_LADDER } from '../model/AppSettings'
import { PlayQueue } from '../core/queue/PlayQueue'
import { nextIndex, prevIndex } from '../core/queue/PlayModePolicy'
import { SourceResolver } from '../core/source/SourceResolver'
import { VolumeController } from '../core/volume/VolumeController'
import { toPlayerVolume } from '../core/volume/VolumeScale'

const TAG = 'PlayerKernel'
const DOMAIN = 0x0001

export type PlayerStatus = 'idle' | 'loading' | 'playing' | 'paused' | 'completed' | 'error'

export interface PlayerSnapshotListener {
  onTrackChanged(music: MusicInfo | undefined, index: number): void
  onStatusChanged(status: PlayerStatus): void
  onDurationChanged(sec: number): void
  /** 播放进度推进（媒体会话据此节流回写通知栏进度条） */
  onProgressChanged(sec: number): void
}

/**
 * 播放内核需要的外部能力（由编排层注入，避免反向依赖 store/）
 */
export interface PlayerKernelConfig {
  /** 某首歌的音源覆盖（换源播放持久化） */
  getSourceOverride(musicId: string): Promise<string | undefined>
  /** 播放失败通知：内核不直接弹提示，交给上层按上下文处理 */
  onError(message: string): void
}

class PlayerKernelImpl {
  private avPlayer?: media.AVPlayer
  private queue: PlayQueue = new PlayQueue()
  private mode: PlayMode = 'listLoop'
  private quality: PlayQuality = '128k'
  private listener?: PlayerSnapshotListener
  private config?: PlayerKernelConfig
  private volume: VolumeController = new VolumeController()
  /** 快照恢复的起始位置（秒），仅在下一曲目 prepared+play 后生效一次 */
  private pendingSeekSec: number = 0
  /** 播放代次：每次进入 playIndexInternal 自增，旧的异步回调直接丢弃，防切歌串扰 */
  private playToken: number = 0
  /** 等待 initialized 的一次性 waiter（复用 bindPlayer 的唯一 stateChange 监听，避免重复 on 冲掉状态同步） */
  private initWaitToken: number = -1
  private initWaitResolve: (() => void) | null = null
  private initWaitReject: ((e: Error) => void) | null = null
  private initWaitTimer: number = 0
  /** 最近一次失败原因（error 态下供 UI 展示与重试） */
  private lastError: string = ''
  /** 其他应用播放声音时是否自动暂停本应用（对齐上游 player.isHandleAudioFocus） */
  private audioFocusEnabled: boolean = true
  /** 随机模式下是否自动清空已播放列表（对齐上游 player.isAutoCleanPlayedList） */
  private autoCleanPlayedList: boolean = false
  /** 待上报的播放错误（起播前收到的错误先挂起，确认播放器确实失败后再提示用户） */
  private pendingError: string = ''

  init(): void {
    AppStorage.setOrCreate<string>('playerStatus', 'idle')
    AppStorage.setOrCreate<number>('progressTime', 0)
    AppStorage.setOrCreate<number>('maxTime', 0)
    AppStorage.setOrCreate<number>('playIndex', -1)
    AppStorage.setOrCreate<string>('currentMusicId', '')
    AppStorage.setOrCreate<string>('playMode', 'listLoop')
    AppStorage.setOrCreate<string>('playQuality', '128k')
    AppStorage.setOrCreate<string>('currentMusicJson', '')
    AppStorage.setOrCreate<number>('playQueueRev', 0)
    AppStorage.setOrCreate<number>('playerVolume', 100)
    AppStorage.setOrCreate<boolean>('playerMuted', false)
    AppStorage.setOrCreate<boolean>('playerSystemMuted', false)
    // 音量变化实时下发到 AVPlayer
    this.volume.onChange((effective: number) => {
      AppStorage.setOrCreate<number>('playerVolume', effective)
      AppStorage.setOrCreate<boolean>('playerMuted', this.volume.isMuted())
      AppStorage.setOrCreate<boolean>('playerSystemMuted', this.volume.isSystemMuted())
      this.applyVolumeToPlayer(effective)
    })
    // 系统媒体流音量变化（用户在通知面板拖音量条）也要反映到界面
    this.volume.onSystemChange(() => {
      AppStorage.setOrCreate<boolean>('playerSystemMuted', this.volume.isSystemMuted())
    })
  }

  /**
   * 注入外部能力（由编排层在启动时调用一次）。
   * 注入而非直接 import，是为了让 player/ 与 store/ 之间不产生循环引用。
   */
  configure(config: PlayerKernelConfig): void {
    this.config = config
  }

  /** 用设置项里的音量恢复运行时状态（启动时调用），并开始监听系统媒体流音量 */
  async restoreVolume(initialVolume: number): Promise<void> {
    this.volume.init(initialVolume)
    AppStorage.setOrCreate<number>('playerVolume', this.volume.get())
    AppStorage.setOrCreate<boolean>('playerMuted', this.volume.isMuted())
    try {
      await this.volume.observeSystemVolume()
      AppStorage.setOrCreate<boolean>('playerSystemMuted', this.volume.isSystemMuted())
    } catch (e) {
      // 系统音量不可用时不影响应用内音量
      hilog.warn(DOMAIN, TAG, 'observe system volume failed: %{public}s', JSON.stringify(e))
    }
  }

  setListener(listener: PlayerSnapshotListener): void {
    this.listener = listener
  }

  getList(): MusicInfo[] {
    return this.queue.getList()
  }

  getIndex(): number {
    return this.queue.getIndex()
  }

  getCurrentMusic(): MusicInfo | undefined {
    return this.queue.getCurrent()
  }

  getMode(): PlayMode {
    return this.mode
  }

  getStatus(): PlayerStatus {
    return (AppStorage.get<string>('playerStatus') ?? 'idle') as PlayerStatus
  }

  /** 最近一次播放失败原因 */
  getLastError(): string {
    return this.lastError
  }

  setList(musics: MusicInfo[], startIndex: number): void {
    this.pendingSeekSec = 0
    this.queue.clearHistory()
    this.queue.setList(musics, startIndex)
    hilog.info(DOMAIN, TAG, 'queue set: %{public}d item(s), start=%{public}d', this.queue.size, startIndex)
    this.notifyQueueChanged()
    if (this.queue.size == 0) {
      this.stopInternal()
      return
    }
    const idx = Math.min(Math.max(startIndex, 0), this.queue.size - 1)
    void this.playIndexInternal(idx)
  }

  /** 仅装载队列与索引，不触发播放（用于启动恢复快照）；positionSec 为恢复进度（秒） */
  setListWithoutPlay(musics: MusicInfo[], startIndex: number, positionSec: number): void {
    this.queue.clearHistory()
    this.queue.setList(musics, startIndex)
    this.pendingSeekSec = positionSec > 0 ? positionSec : 0
    if (this.queue.size == 0) {
      this.queue.setIndex(-1)
      AppStorage.setOrCreate<number>('playIndex', -1)
    AppStorage.setOrCreate<string>('currentMusicId', '')
      return
    }
    AppStorage.setOrCreate<number>('playIndex', this.queue.getIndex())
  }

  async playIndex(index: number): Promise<void> {
    if (index < 0 || index >= this.queue.size) {
      return
    }
    // 随机模式下手动选曲 = 重新开始随机，已播放的歌曲重新参与（对齐上游 isAutoCleanPlayedList）
    if (this.mode == 'listRandom' && this.autoCleanPlayedList) {
      this.queue.clearHistory()
    }
    await this.playIndexInternal(index)
  }

  async toggle(): Promise<void> {
    const player = this.avPlayer
    if (player == undefined) {
      if (this.queue.size > 0 && this.queue.getIndex() >= 0) {
        await this.playIndexInternal(this.queue.getIndex())
      }
      return
    }
    const status = this.getStatus()
    try {
      if (status == 'playing') {
        await player.pause()
      } else if (status == 'paused') {
        await player.play()
      } else if (status == 'error') {
        // 失败后点击 = 重试当前曲目
        await this.playIndexInternal(this.queue.getIndex())
      } else if (status == 'completed' || status == 'idle') {
        // completed/idle 下 seek+play 不可靠，重建播放器重播当前曲目
        await this.playIndexInternal(this.queue.getIndex())
      } else {
        // loading 中忽略，避免与起播流程竞态；按钮保持 loading 态直到 playing
        hilog.info(DOMAIN, TAG, 'toggle ignored in status: %{public}s', status)
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'toggle failed: %{public}s', JSON.stringify(e))
    }
  }

  async pause(): Promise<void> {
    const player = this.avPlayer
    if (player == undefined) {
      return
    }
    try {
      await player.pause()
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'pause failed: %{public}s', JSON.stringify(e))
    }
  }

  /**
   * 进度跳转。目标越界时钳制到 [0, 时长]；时长未知（0）时按 0 处理。
   */
  async seek(sec: number): Promise<void> {
    const player = this.avPlayer
    if (player == undefined) {
      return
    }
    const maxSec: number = AppStorage.get<number>('maxTime') ?? 0
    let target: number = sec
    if (isNaN(target) || target < 0) {
      target = 0
    }
    if (maxSec > 0 && target > maxSec) {
      target = maxSec
    }
    try {
      player.seek(Math.floor(target * 1000), media.SeekMode.SEEK_PREV_SYNC)
      AppStorage.setOrCreate<number>('progressTime', target)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'seek failed: %{public}s', JSON.stringify(e))
    }
  }

  async skipNext(): Promise<void> {
    if (this.queue.size == 0) {
      return
    }
    const next = nextIndex(this.mode, this.queue.getIndex(), this.queue.size)
    if (next < 0) {
      return
    }
    await this.playIndexInternal(next)
  }

  async skipPrev(): Promise<void> {
    if (this.queue.size == 0) {
      return
    }
    // 随机模式下「上一首」优先回到播放历史（消费掉该条历史，避免反复按原地打转）
    if (this.mode == 'listRandom') {
      const target: number = this.consumeHistoryIndex()
      if (target >= 0) {
        await this.playIndexInternal(target, true)
        return
      }
    }
    const prev = prevIndex(this.mode, this.queue.getIndex(), this.queue.size)
    if (prev < 0) {
      return
    }
    await this.playIndexInternal(prev)
  }

  /**
   * 消费一条可用于「上一首」的播放历史：取出栈顶、找到它在当前队列中的索引，
   * 并把该条历史弹出。历史歌曲若已被移出队列则丢弃并继续看下一条。
   * 全部不可用时返回 -1（调用方退回随机选取）。
   */
  private consumeHistoryIndex(): number {
    for (let guard = 0; guard < 10; guard++) {
      const top: MusicInfo | undefined = this.queue.peekHistory()
      if (top == undefined) {
        return -1
      }
      this.queue.popHistory()
      const idx: number = this.queue.indexOfId(top.id)
      if (idx >= 0) {
        return idx
      }
    }
    return -1
  }

  /** 队列版本号：任何队列结构变化时递增（UI @Watch 刷新播放队列弹层） */
  private notifyQueueChanged(): void {
    const rev = AppStorage.get<number>('playQueueRev') ?? 0
    AppStorage.setOrCreate<number>('playQueueRev', rev + 1)
  }

  /**
   * 从播放队列移除指定曲目（对齐上游 PlayDetail 播放列表的移除行为）：
   * - 移除非当前曲：数组删除，索引修正；
   * - 移除当前曲：播放移除后同位置的原下一曲（队列尾则从头循环）；队列清空则停止。
   */
  async removeAt(index: number): Promise<void> {
    const result = this.queue.removeAt(index)
    if (!result.removed) {
      return
    }
    if (this.queue.size == 0) {
      this.stopInternal()
      this.notifyQueueChanged()
      return
    }
    AppStorage.setOrCreate<number>('playIndex', this.queue.getIndex())
    if (result.removedCurrent) {
      await this.playIndexInternal(result.nextIndex)
    }
    this.notifyQueueChanged()
  }

  /**
   * 队列内重排：把 from 位置的曲目移到 to 位置（当前播放曲目跟着搬家）。
   */
  moveInQueue(from: number, to: number): boolean {
    const moved: boolean = this.queue.move(from, to)
    if (!moved) {
      return false
    }
    AppStorage.setOrCreate<number>('playIndex', this.queue.getIndex())
    this.notifyQueueChanged()
    return true
  }

  /** 清空播放队列并停止播放 */
  async clearQueue(): Promise<void> {
    this.queue.clear()
    this.stopInternal()
    this.notifyQueueChanged()
  }

  /**
   * 换源播放（对齐上游换源行为）：用新源的同一首歌替换队列当前位置并立即播放，
   * 队列其余曲目保持不变。
   */
  async replaceCurrent(music: MusicInfo): Promise<void> {
    const index: number = this.queue.getIndex()
    if (index < 0 || index >= this.queue.size) {
      return
    }
    this.queue.replaceAt(index, music)
    AppStorage.setOrCreate<string>('currentMusicJson', JSON.stringify(music))
    this.notifyQueueChanged()
    await this.playIndexInternal(index)
  }

  setMode(mode: PlayMode): void {
    this.mode = mode
    AppStorage.setOrCreate<string>('playMode', mode)
  }

  /** 设置在线播放音质（对齐上游 playerSetting.playQuality） */
  setPlayQuality(quality: PlayQuality): void {
    this.quality = quality
    AppStorage.setOrCreate<string>('playQuality', quality)
  }

  /**
   * 其他应用播放声音时是否自动暂停本应用（对齐上游 player.isHandleAudioFocus）。
   * 开启 = 共享音频中断单元（SHARE_MODE），关闭 = 各自独立（INDEPENDENT_MODE）。
   */
  setAudioFocusEnabled(on: boolean): void {
    this.audioFocusEnabled = on
    this.applyInterruptMode()
  }

  /** 随机模式下是否自动清空已播放列表（对齐上游 player.isAutoCleanPlayedList） */
  setAutoCleanPlayedList(on: boolean): void {
    this.autoCleanPlayedList = on
  }

  /**
   * 把音频中断模式应用到当前播放器。
   *
   * 【坑】audioInterruptMode **只允许在 prepared/playing/paused/completed 状态下设置**。
   * 在 idle/initialized 阶段设置会触发 AVPlayer 5400102「Operation not allowed」，
   * 而该错误是通过 player.on('error') **回调**上报的（try-catch 抓不到），
   * 表现为「播放时弹一个英文报错，但歌照常在放」。
   * 因此这里加状态守卫，并由 stateChange 在 prepared 后补设一次。
   */
  private applyInterruptMode(): void {
    const player = this.avPlayer
    if (player == undefined) {
      return
    }
    const state: string = player.state
    if (state != 'prepared' && state != 'playing' && state != 'paused' && state != 'completed') {
      return
    }
    try {
      player.audioInterruptMode = this.audioFocusEnabled
        ? audio.InterruptMode.SHARE_MODE : audio.InterruptMode.INDEPENDENT_MODE
      hilog.info(DOMAIN, TAG, 'audioInterruptMode applied: %{public}s',
        this.audioFocusEnabled ? 'SHARE_MODE' : 'INDEPENDENT_MODE')
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'set audioInterruptMode failed: %{public}s', JSON.stringify(e))
    }
  }

  /** 设置音量（0–100，越界自动钳制） */
  setVolume(v: number): void {
    this.volume.set(v)
  }

  getVolume(): number {
    return this.volume.get()
  }

  isMuted(): boolean {
    return this.volume.isMuted()
  }

  toggleMute(): void {
    this.volume.toggleMute()
  }

  /**
   * 解析本曲实际请求音质（含降级）：
   * 1. 想要的质量在 meta.qualitys 中存在 → 直接用；
   * 2. 否则按 flac24bit→flac→320k→128k 降级链取请求质量及以下的最高可用；
   * 3. 全无 → 取列表第一个（避免对不存在的质量发起必然失败的请求）。
   */
  private resolveQuality(music: MusicInfo): string {
    const want = this.quality
    const meta = music.meta as MusicInfoMetaOnline
    const qualitys = meta.qualitys
    if (qualitys == undefined || qualitys.length == 0) {
      return '128k'
    }
    for (let i = 0; i < qualitys.length; i++) {
      if (qualitys[i].type == want) {
        return want
      }
    }
    const wantIdx = QUALITY_LADDER.indexOf(want)
    for (let i = wantIdx < 0 ? 0 : wantIdx; i < QUALITY_LADDER.length; i++) {
      for (let j = 0; j < qualitys.length; j++) {
        if (qualitys[j].type == QUALITY_LADDER[i]) {
          return QUALITY_LADDER[i]
        }
      }
    }
    return qualitys[0].type
  }

  async release(): Promise<void> {
    await this.destroyPlayer()
  }

  getProgressSec(): number {
    return AppStorage.get<number>('progressTime') ?? 0
  }

  /** 暴露给 MediaSessionController 读取用于封面/元数据 */
  getFdPathOfCurrent(): string | undefined {
    const music = this.getCurrentMusic()
    if (music == undefined) {
      return undefined
    }
    return toLocalMeta(music.meta).filePath
  }

  private setStatus(status: PlayerStatus): void {
    AppStorage.setOrCreate<string>('playerStatus', status)
    if (this.listener != undefined) {
      this.listener.onStatusChanged(status)
    }
  }

  private stopInternal(): void {
    this.queue.setIndex(-1)
    AppStorage.setOrCreate<number>('playIndex', -1)
    AppStorage.setOrCreate<string>('currentMusicId', '')
    AppStorage.setOrCreate<string>('currentMusicJson', '')
    AppStorage.setOrCreate<number>('progressTime', 0)
    AppStorage.setOrCreate<number>('maxTime', 0)
    this.setStatus('idle')
    // 队列清空时必须销毁底层播放器，否则声音还在播但 UI 已是 idle
    void this.destroyPlayer()
  }

  /**
   * 起播指定索引的曲目。
   * @param isBackNavigation 是否由「上一首」触发。回退导航**不**把当前曲目压入播放历史，
   *        否则历史会被反复覆盖，随机模式下连续按「上一首」会原地打转。
   */
  private async playIndexInternal(index: number, isBackNavigation: boolean = false): Promise<void> {
    if (index < 0 || index >= this.queue.size) {
      return
    }
    // 切歌前把上一首记入播放历史（随机模式下「上一首」的来源）
    if (!isBackNavigation) {
      const previous: MusicInfo | undefined = this.queue.getCurrent()
      if (previous != undefined && this.queue.getIndex() !== index) {
        this.queue.pushHistory(previous)
      }
    }
    this.queue.setIndex(index)
    const music = this.queue.getCurrent()
    if (music == undefined) {
      return
    }
    hilog.info(DOMAIN, TAG, 'play index %{public}d -> %{public}s | %{public}s', index, music.name, music.id)
    AppStorage.setOrCreate<number>('playIndex', index)
    // 当前播放曲目 id：列表高亮必须按 id 判定，不能用 playIndex（那是「队列内索引」，
    // 当播放队列与当前列表不是同一份数据时会指错行 → 看起来像「点 A 播 B」）
    AppStorage.setOrCreate<string>('currentMusicId', music.id)
    AppStorage.setOrCreate<string>('currentMusicJson', JSON.stringify(music))
    AppStorage.setOrCreate<number>('progressTime', 0)
    AppStorage.setOrCreate<number>('maxTime', 0)
    this.lastError = ''
    if (this.listener != undefined) {
      this.listener.onTrackChanged(music, index)
    }

    const isLocal = isLocalInfo(music.meta)
    await this.destroyPlayer()
    this.setStatus('loading')

    // 每次进入起播递增代次，旧的异步回调直接丢弃
    const token: number = ++this.playToken

    if (!isLocal) {
      const played: boolean = await this.playOnline(music, token)
      if (!played && !this.isStale(token)) {
        this.setStatus('error')
      }
      return
    }

    const filePath = toLocalMeta(music.meta).filePath
    let fd = -1
    try {
      const stat = fs.statSync(filePath)
      fd = fs.openSync(filePath, fs.OpenMode.READ_ONLY).fd
      const player = await media.createAVPlayer()
      if (this.isStale(token)) {
        try {
          fs.closeSync(fd)
        } catch (ignored) {
          // ignore
        }
        try {
          await player.release()
        } catch (ignored) {
          // ignore
        }
        return
      }
      this.bindPlayer(player)
      const waitReady: Promise<void> = this.waitForInitialized(token, 10000)
      player.fdSrc = { fd: fd, offset: 0, length: stat.size }
      await waitReady
      if (this.isStale(token)) {
        return
      }
      await player.prepare()
      if (this.isStale(token)) {
        return
      }
      // 新建的播放器要重新下发当前音量，否则切歌后音量回到默认值
      await this.applyVolumeToPlayer(this.volume.get())
      await player.play()
      await this.applyPendingSeek()
    } catch (e) {
      if (this.isStale(token)) {
        return
      }
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'play failed(%{public}s): %{public}s', filePath, JSON.stringify(err))
      // fd 的关闭统一交给 destroyPlayer（内部有 try-catch 防重复关闭）
      await this.destroyPlayer()
      this.lastError = err.message ?? '本地文件播放失败'
      this.notifyError(this.lastError)
      this.setStatus('error')
    }
  }

  /**
   * 在线播放：按候选链逐源取直链并试播，任一源失败（取链接失败或起播失败）自动降级到下一个源。
   * 返回是否成功起播。
   */
  private async playOnline(music: MusicInfo, token: number): Promise<boolean> {
    const quality = this.resolveQuality(music)
    let lastError = ''
    const config = this.config
    const resolver: SourceResolver = SourceResolver.getInstance()
    const priority: string[] = resolver.getPriority()

    let overrideSourceId: string | undefined = undefined
    if (config != undefined) {
      try {
        overrideSourceId = await config.getSourceOverride(music.id)
        if (this.isStale(token)) {
          return false
        }
      } catch (ignored) {
        // 覆盖读取失败则走正常优先级链
      }
    }
    if (overrideSourceId != undefined && overrideSourceId.length > 0) {
      hilog.info(DOMAIN, TAG, 'using source override for %{public}s: %{public}s', music.id, overrideSourceId)
    }
    const candidates: string[] = resolver.buildCandidates(music, priority, overrideSourceId)

    for (let c = 0; c < candidates.length; c++) {
      if (this.isStale(token)) {
        return false
      }
      const sourceId: string = candidates[c]
      let onlineUrl = ''
      try {
        onlineUrl = await resolver.getMusicUrlFrom(sourceId, music, quality)
      } catch (e) {
        lastError = (e as Error).message ?? `${sourceId} error`
        hilog.warn(DOMAIN, TAG, 'source %{public}s getMusicUrl failed: %{public}s', sourceId, lastError)
        continue
      }
      if (this.isStale(token)) {
        return false
      }
      if (onlineUrl.length == 0) {
        continue
      }
      hilog.info(DOMAIN, TAG, 'got url from source: %{public}s', sourceId)
      try {
        const player = await media.createAVPlayer()
        if (this.isStale(token)) {
          try {
            await player.release()
          } catch (ignored) {
            // ignore
          }
          return false
        }
        this.bindPlayer(player)
        // 先注册等待，再设置 url，避免 initialized 事件竞态丢失
        const waitReady: Promise<void> = this.waitForInitialized(token, 10000)
        player.url = onlineUrl
        await waitReady
        if (this.isStale(token)) {
          return false
        }
        await player.prepare()
        if (this.isStale(token)) {
          return false
        }
        // 新建的播放器要重新下发当前音量，否则切歌后音量回到默认值
        await this.applyVolumeToPlayer(this.volume.get())
        await player.play()
        await this.applyPendingSeek()
        return true
      } catch (e) {
        const err = e as BusinessError
        lastError = err.message ?? 'play failed'
        hilog.warn(DOMAIN, TAG, 'source %{public}s play failed, try next: %{public}s', sourceId, JSON.stringify(err))
        if (!this.isStale(token)) {
          await this.destroyPlayer()
        } else {
          return false
        }
      }
    }

    if (!this.isStale(token)) {
      const msg = lastError.length > 0 ? `所有音源均失败：${lastError}` : '音源未返回播放链接'
      this.lastError = msg
      this.notifyError(msg)
      await this.destroyPlayer()
    }
    return false
  }

  /**
   * 把音量下发到当前播放器（无播放器时静默忽略，等新播放器建好再补一次）。
   *
   * 【坑】AVPlayer.setVolume 的取值范围是 **0.00–1.00**（相对音量，1.00 = 最大音量），
   * 而应用内音量是 0–100 的整数。直接传 100 会让 AVPlayer 报
   * errorCode 401「Invalid Parameter: invalid parameters, check volume level」，
   * 该错误通过 player.on('error') 回调上报 —— 于是表现为「播放时弹出一个英文报错，
   * 但歌照常放」（setVolume 失败被 try-catch 吞掉，播放流程继续）。
   * 因此这里必须先换算成 0.0–1.0 的比例。
   */
  private async applyVolumeToPlayer(volume: number): Promise<void> {
    const player = this.avPlayer
    if (player == undefined) {
      return
    }
    const ratio: number = toPlayerVolume(volume)
    try {
      await player.setVolume(ratio)
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'setVolume failed: %{public}s', JSON.stringify(e))
    }
  }

  /** 播放失败通知（交给上层决定如何提示） */
  private notifyError(message: string): void {
    const config = this.config
    if (config == undefined) {
      return
    }
    try {
      config.onError(message)
    } catch (ignored) {
      // 提示失败不影响播放流程
    }
  }

  /** 应用快照恢复的起始进度（一次性），prepared+play 后调用 */
  private async applyPendingSeek(): Promise<void> {
    const sec = this.pendingSeekSec
    this.pendingSeekSec = 0
    if (sec <= 0) {
      return
    }
    const maxSec = AppStorage.get<number>('maxTime') ?? 0
    const target = maxSec > 0 ? Math.min(sec, Math.max(maxSec - 1, 0)) : sec
    try {
      AppStorage.setOrCreate<number>('progressTime', target)
      await this.seek(target)
    } catch (ignored) {
      // seek 失败则从头播放
    }
  }

  private isStale(token: number): boolean {
    return token !== this.playToken
  }

  /**
   * 等待 AVPlayer 进入 initialized 态（set url/fdSrc 后触发）。
   * 注意：同一事件重复 player.on 会冲掉 bindPlayer 的状态同步监听，
   * 因此这里只登记 resolver，由 bindPlayer 的唯一 stateChange 监听统一分发。
   * 调用方必须先调用本方法、再设置 url/fdSrc，避免事件竞态丢失。
   */
  private waitForInitialized(token: number, timeoutMs: number = 10000): Promise<void> {
    this.clearInitWaiter()
    return new Promise<void>((resolve, reject) => {
      this.initWaitToken = token
      this.initWaitResolve = resolve
      this.initWaitReject = reject
      this.initWaitTimer = setTimeout(() => {
        if (this.initWaitToken == token) {
          const rej = this.initWaitReject
          this.clearInitWaiter()
          if (rej != null) {
            rej(new Error('wait for initialized timeout'))
          }
        }
      }, timeoutMs)
    })
  }

  private clearInitWaiter(): void {
    this.initWaitToken = -1
    this.initWaitResolve = null
    this.initWaitReject = null
    if (this.initWaitTimer != 0) {
      clearTimeout(this.initWaitTimer)
      this.initWaitTimer = 0
    }
  }

  /** bindPlayer 的 stateChange 分发等待中的 initialized/error */
  private dispatchInitWaiter(state: string): void {
    if (this.initWaitToken < 0) {
      return
    }
    if (state != 'initialized' && state != 'error') {
      return
    }
    const token = this.initWaitToken
    const res = this.initWaitResolve
    const rej = this.initWaitReject
    this.clearInitWaiter()
    if (this.isStale(token)) {
      return
    }
    if (state == 'initialized') {
      if (res != null) {
        res()
      }
    } else {
      if (rej != null) {
        rej(new Error('player error before initialized'))
      }
    }
  }

  private bindPlayer(player: media.AVPlayer): void {
    this.avPlayer = player

    player.on('stateChange', (state: string) => {
      hilog.info(DOMAIN, TAG, 'stateChange: %{public}s', state)
      // 先分发给等待 initialized 的起播流程（P0：不能再单独 on一次，否则会冲掉本监听）
      this.dispatchInitWaiter(state)
      if (state == 'prepared') {
        // prepared 之后才能设置 audioInterruptMode（见 applyInterruptMode 的说明）
        this.applyInterruptMode()
      }
      if (state == 'playing') {
        // 起播成功：之前挂起的起播前错误作废，避免污染下一次失败上报
        this.pendingError = ''
        this.setStatus('playing')
      } else if (state == 'paused') {
        this.setStatus('paused')
      } else if (state == 'completed') {
        this.setStatus('completed')
        void this.onPlayComplete()
      } else if (state == 'error') {
        this.setStatus('error')
        this.reportPendingError()
      }
    })

    player.on('timeUpdate', (time: number) => {
      const sec: number = time / 1000
      AppStorage.setOrCreate<number>('progressTime', sec)
      if (this.listener != undefined) {
        this.listener.onProgressChanged(sec)
      }
    })

    player.on('durationUpdate', (duration: number) => {
      AppStorage.setOrCreate<number>('maxTime', duration / 1000)
      if (this.listener != undefined) {
        this.listener.onDurationChanged(duration / 1000)
      }
    })

    // 音量是否真正生效以本事件为准（SDK 明确：setVolume 成功才会回调）
    player.on('volumeChange', (volume: number) => {
      hilog.info(DOMAIN, TAG, 'volumeChange: %{public}d', volume)
    })

    player.on('error', (err: BusinessError) => {
      const state: string = player.state
      hilog.error(DOMAIN, TAG, 'player error(%{public}d, state=%{public}s): %{public}s', err.code, state, err.message)
      // 并非所有 error 都会中断播放：例如音量参数非法（errorCode 401）这类非致命错误，
      // 播放器仍处于 playing/paused，此时不该弹「播放失败」——否则用户会看到
      // 「弹了个报错但歌照常在放」。只有播放器确实不再可用时才上报失败。
      // 并非所有 error 都会中断播放：
      //  - 播放仍在进行（playing/paused/prepared/completed）→ 忽略
      //    （如音量参数非法 errorCode 401、误在 idle 阶段设置播放器属性等）
      //  - 起播前（idle/initialized）的错误 → 先挂起：若播放器随后真的进入 error 态
      //    再上报；若正常起播，则说明这个错误不影响播放，不打扰用户
      const alive: boolean = state == 'playing' || state == 'paused' ||
        state == 'prepared' || state == 'completed'
      if (alive) {
        return
      }
      this.pendingError = `${err.code}: ${err.message ?? '播放出错'}`
      if (state == 'error') {
        this.reportPendingError()
      }
    })
  }

  /** 上报挂起的播放错误；没有挂起错误则什么都不做 */
  private reportPendingError(): void {
    if (this.pendingError.length == 0) {
      return
    }
    const message: string = this.pendingError
    this.pendingError = ''
    this.lastError = message
    this.notifyError(message)
    this.setStatus('error')
  }

  private async onPlayComplete(): Promise<void> {
    if (this.mode == 'singleLoop') {
      // completed 状态下 seek+play 不可靠，重建播放器实现单曲循环
      await this.playIndexInternal(this.queue.getIndex())
      return
    }
    // listLoop / listRandom：自动切下一曲
    try {
      await this.skipNext()
    } catch (e) {
      // 自动下一首失败会让播放静默停住，必须留痕
      hilog.error(DOMAIN, TAG, 'auto play next failed: %{public}s', JSON.stringify(e))
    }
  }

  private async destroyPlayer(): Promise<void> {
    // 销毁时唤醒等待中的起播流程，避免旧代次挂死 10s
    if (this.initWaitToken >= 0) {
      const rej = this.initWaitReject
      this.clearInitWaiter()
      if (rej != null) {
        rej(new Error('player destroyed'))
      }
    }
    const player = this.avPlayer
    this.avPlayer = undefined
    if (player == undefined) {
      return
    }
    try {
      // fd 由 AVPlayer 生命周期内使用，release 后统一关闭
      const fdSrc = player.fdSrc
      player.off('stateChange')
      player.off('timeUpdate')
      player.off('durationUpdate')
      player.off('error')
      await player.release()
      if (fdSrc != undefined && fdSrc.fd >= 0) {
        try {
          fs.closeSync(fdSrc.fd)
        } catch (ignored) {
          // ignore
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'release player failed: %{public}s', JSON.stringify(e))
    }
  }
}

export const PlayerKernel: PlayerKernelImpl = new PlayerKernelImpl()
