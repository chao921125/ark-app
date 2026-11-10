/**
 * 播放详情页 — 对齐上游 `src/screens/PlayDetail`（MVP：单布局）
 * 封面 / 歌曲信息 / 歌词 / 进度 / 音量 / 播放控制 / 模式切换 / 歌词导入 / 播放队列
 *
 * 【模块边界】页面只与编排层 PlayerFacade 打交道，不直接接触播放内核与仓储层。
 */
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MusicInfo, MusicInfoMetaOnline } from '../model/MusicInfo'
import { ListPersistence } from '../persistence/ListPersistence'
import { PlayerFacade } from '../app/PlayerFacade'
import { ListStore } from '../store/ListStore'
import { LyricManager } from '../lyric/LyricManager'
import { LyricSearch } from '../lyric/LyricSearch'
import { LyricLine } from '../lyric/LyricParser'
import { FileScanner } from '../utils/FileScanner'
import { formatTime } from '../utils/FormatUtil'
import { LyricView } from '../components/LyricView'
import { SourceResolver } from '../core/source/SourceResolver'
import { PlayMode } from '../model/AppSettings'

const TAG = 'PlayDetail'
const DOMAIN = 0x0001

@Component
export struct PlayDetail {
  @StorageLink('showPlayDetail') showPlayDetail: boolean = false
  @StorageLink('currentMusicJson') @Watch('onMusicChange') currentMusicJson: string = ''
  @StorageLink('playerStatus') playerStatus: string = 'idle'
  @StorageLink('progressTime') progressTime: number = 0
  @StorageLink('maxTime') maxTime: number = 0
  @StorageLink('playMode') playMode: string = 'listLoop'
  @StorageLink('showFloatLyric') showFloatLyric: boolean = false
  @StorageLink('playQueueRev') @Watch('refreshQueue') playQueueRev: number = 0
  @StorageLink('likeListRev') @Watch('refreshLiked') likeListRev: number = 0
  /** 当前播放曲目 id（队列点击按 id 定位，避免用过期 index 播错歌） */
  @StorageLink('currentMusicId') currentMusicId: string = ''
  @StorageLink('playerVolume') playerVolume: number = 100
  @StorageLink('playerMuted') playerMuted: boolean = false
  @StorageLink('playerSystemMuted') playerSystemMuted: boolean = false
  @State liked: boolean = false
  @State musicName: string = ''
  @State musicSinger: string = ''
  @State lyricLines: LyricLine[] = []
  @State lyricVisible: boolean = false
  @State importingLyric: boolean = false
  /** 正在跨源检索歌词 */
  @State searchingLyric: boolean = false
  /** 最近一次歌词检索是否落空（用于占位提示区分「无歌词」与「检索失败」） */
  @State lyricSearchMissed: boolean = false
  @State showQueueSheet: boolean = false
  @State queueList: MusicInfo[] = []
  @State queueIndex: number = -1
  // 队列弹层内的「保存为歌单」输入态（内联展开，避免弹层套弹层）
  @State saveMode: boolean = false
  @State saveListName: string = ''
  // 进度条拖拽状态机：拖拽中锁住滑块值，避免 timeUpdate 每秒回写导致滑块跳变
  @State dragging: boolean = false
  @State dragValue: number = 0
  // 换源弹层（四期）
  @State showSourceSheet: boolean = false
  @State candidateSourceId: string = ''
  @State candidates: MusicInfo[] = []
  @State sourceSearching: boolean = false
  @State sourceSearched: boolean = false
  private music?: MusicInfo

  aboutToAppear(): void {
    this.onMusicChange()
  }

  /** 队列结构/位置变化（playQueueRev 或切歌）时刷新弹层快照 */
  refreshQueue(): void {
    this.queueList = PlayerFacade.getQueue().slice()
    this.queueIndex = PlayerFacade.getQueueIndex()
  }

  refreshLiked(): void {
    this.liked = this.music != undefined && ListPersistence.isLiked(this.music.id)
  }

  private async toggleLike(): Promise<void> {
    if (this.music == undefined) {
      return
    }
    try {
      const liked = await ListPersistence.toggleLike(this.music)
      promptAction.showToast({ message: liked ? '已加入喜欢的音乐' : '已取消收藏', duration: 1500 })
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'toggle like failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '收藏操作失败，请重试', duration: 1800 })
    }
  }

  // ---- 换源播放（四期）：用其他在线音源搜索同曲并替换当前播放 ----

  private sourceLabel(id: string): string {
    if (id == 'kw') {
      return 'KW'
    }
    if (id == 'wy') {
      return 'WY'
    }
    if (id == 'kg') {
      return 'KG'
    }
    if (id == 'tx') {
      return 'TX'
    }
    if (id == 'mg') {
      return 'MG'
    }
    return id
  }

  private sourceIds: string[] = ['kw', 'wy', 'kg', 'tx', 'mg']

  private openSourceSheet(): void {
    if (this.music == undefined) {
      return
    }
    this.candidateSourceId = ''
    this.candidates = []
    this.sourceSearching = false
    this.sourceSearched = false
    this.showSourceSheet = true
  }

  private searchKeyword(): string {
    const music = this.music
    if (music == undefined) {
      return ''
    }
    return music.singer.length > 0 ? `${music.singer} ${music.name}` : music.name
  }

  private async searchSource(sourceId: string): Promise<void> {
    const music = this.music
    if (music == undefined || this.sourceSearching) {
      return
    }
    this.sourceSearching = true
    this.candidateSourceId = sourceId
    this.sourceSearched = false
    try {
      const list = await SourceResolver.getInstance().search(sourceId, this.searchKeyword())
      // 过滤掉当前曲目自身（同 id 时避免"换到自己"）
      this.candidates = list.filter(m => m.id != music.id)
      this.sourceSearched = true
      if (this.candidates.length == 0) {
        promptAction.showToast({ message: `${this.sourceLabel(sourceId)}未找到匹配歌曲`, duration: 1500 })
      }
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'change source search failed: %{public}s', JSON.stringify(err))
      this.candidates = []
      this.sourceSearched = true
      promptAction.showToast({ message: `${this.sourceLabel(sourceId)}搜索失败`, duration: 1500 })
    } finally {
      this.sourceSearching = false
    }
  }

  private async applyCandidate(music: MusicInfo): Promise<void> {
    const target = this.sourceLabel(this.candidateSourceId)
    try {
      await PlayerFacade.replaceCurrent(music)
      // 保存音源覆盖设置（换源播放持久化）
      await PlayerFacade.setSourceOverride(music.id, this.candidateSourceId)
      this.showSourceSheet = false
      promptAction.showToast({ message: `已切换到${target}播放`, duration: 1800 })
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'apply candidate failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '换源失败，请重试', duration: 1800 })
    }
  }

  private candidateSubtitle(item: MusicInfo): string {
    const meta = item.meta as MusicInfoMetaOnline
    const album = meta.albumName != undefined ? meta.albumName : ''
    if (item.singer.length > 0 && album.length > 0) {
      return `${item.singer} · ${album}`
    }
    return item.singer.length > 0 ? item.singer : album
  }

  onMusicChange(): void {
    // 切歌时退出拖拽态，否则滑块会停在上一首的进度上
    this.dragging = false
    if (this.currentMusicJson.length == 0) {
      this.musicName = ''
      this.musicSinger = ''
      this.lyricLines = []
      return
    }
    try {
      this.music = JSON.parse(this.currentMusicJson) as MusicInfo
      this.musicName = this.music.name
      this.musicSinger = this.music.singer
    } catch (e) {
      this.music = undefined
    }
    this.refreshQueue()
    this.refreshLiked()
    void this.reloadLyric()
    // 切歌后同步按新歌曲检索歌词（原来只有被动加载，本地导入的歌永远拿不到在线歌词）
    if (this.music != undefined) {
      void this.searchLyric()
    }
  }

  private async reloadLyric(): Promise<void> {
    try {
      const lines = await LyricManager.loadForMusic(this.music)
      this.lyricLines = lines
      this.lyricVisible = lines.length > 0
    } catch (e) {
      // 歌词加载失败只降级为「无歌词」，不应让详情页崩掉
      hilog.warn(DOMAIN, TAG, 'reload lyric failed: %{public}s', JSON.stringify(e))
      this.lyricLines = []
      this.lyricVisible = false
    }
  }

  /**
   * 按当前歌曲检索歌词：跨音源查找（本地导入的歌会用歌名+歌手反查同名歌曲），
   * 检索结果直接展示；切歌后会自动重新检索。
   */
  private async searchLyric(): Promise<void> {
    if (this.searchingLyric || this.music == undefined) {
      return
    }
    this.searchingLyric = true
    this.lyricSearchMissed = false
    try {
      const result = await LyricSearch.search(this.music)
      if (result.found) {
        this.lyricLines = result.lines
        this.lyricVisible = true
        promptAction.showToast({ message: `已找到歌词（${result.sourceId}）`, duration: 1500 })
      } else {
        this.lyricLines = []
        this.lyricVisible = false
        this.lyricSearchMissed = true
        promptAction.showToast({ message: '未检索到歌词', duration: 1800 })
      }
    } catch (e) {
      this.lyricLines = []
      this.lyricVisible = false
      this.lyricSearchMissed = true
      hilog.error(DOMAIN, TAG, 'search lyric failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '歌词检索失败', duration: 1800 })
    } finally {
      this.searchingLyric = false
    }
  }

  private async importLyric(): Promise<void> {
    if (this.importingLyric || this.music == undefined) {
      return
    }
    const context = getContext(this) as common.UIAbilityContext
    this.importingLyric = true
    try {
      const uri = await FileScanner.pickLyricFile(context)
      if (uri.length > 0 && this.music != undefined) {
        const ok = await FileScanner.importLyricFor(this.music, uri)
        if (ok) {
          promptAction.showToast({ message: '歌词已导入', duration: 1500 })
          await this.reloadLyric()
        } else {
          promptAction.showToast({ message: '歌词导入失败', duration: 1500 })
        }
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'import lyric failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '歌词导入失败', duration: 1800 })
    } finally {
      this.importingLyric = false
    }
  }

  private async switchMode(): Promise<void> {
    const order: PlayMode[] = ['listLoop', 'listRandom', 'singleLoop']
    const cur = this.playMode as PlayMode
    const next = order[(order.indexOf(cur) + 1) % order.length]
    try {
      await PlayerFacade.setMode(next)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'switch play mode failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '切换播放模式失败', duration: 1800 })
    }
  }

  private modeIcon(mode: string): Resource {
    if (mode == 'listRandom') {
      return $r('app.media.ic_mode_random')
    }
    if (mode == 'singleLoop') {
      return $r('app.media.ic_mode_single')
    }
    return $r('app.media.ic_mode_list')
  }

  private modeLabel(mode: string): string {
    if (mode == 'listRandom') {
      return '列表随机'
    }
    if (mode == 'singleLoop') {
      return '单曲循环'
    }
    return '列表循环'
  }

  /** 队列内上移/下移 */
  private moveInQueue(from: number, to: number): void {
    if (PlayerFacade.moveInQueue(from, to)) {
      this.refreshQueue()
    }
  }

  private clearQueue(): void {
    void PlayerFacade.clearQueue()
    this.showQueueSheet = false
    promptAction.showToast({ message: '播放队列已清空', duration: 1500 })
  }

  /** 把当前播放队列另存为一个新歌单 */
  private async confirmSaveQueue(): Promise<void> {
    const name: string = this.saveListName.trim()
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入歌单名称', duration: 1500 })
      return
    }
    let count: number = 0
    try {
      count = await PlayerFacade.saveQueueAsList(name)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save queue as list failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '保存歌单失败，请重试', duration: 1800 })
      return
    }
    this.saveMode = false
    this.saveListName = ''
    if (count > 0) {
      promptAction.showToast({ message: `已保存 ${count} 首到「${name}」`, duration: 1800 })
    } else {
      promptAction.showToast({ message: '保存失败：队列为空', duration: 1500 })
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶栏
        Row() {
          Image($r('app.media.ic_expand'))
            .width(24)
            .height(24)
            .fillColor($r('app.color.text_primary'))
            .onClick(() => {
              this.showPlayDetail = false
            })
          Text('正在播放')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          // 换源播放（四期）
          Image($r('app.media.ic_goto'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.text_primary'))
            .margin({ right: 14 })
            .onClick(() => {
              this.openSourceSheet()
            })
          // 收藏当前歌曲（对齐上游 PlayDetail like 按钮）
          Text('♥')
            .fontSize(20)
            .fontColor(this.liked ? '#E05454' : $r('app.color.text_primary'))
            .margin({ right: 14 })
            .onClick(() => {
              void this.toggleLike()
            })
          // 悬浮歌词开关
          Image($r('app.media.ic_float'))
            .width(22)
            .height(22)
            .fillColor(this.showFloatLyric ? $r('app.color.theme_primary') : $r('app.color.text_primary'))
            .margin({ right: 14 })
            .onClick(() => {
              const next = !this.showFloatLyric
              void ListStore.setShowFloatLyric(next)
              promptAction.showToast({ message: next ? '悬浮歌词已开启' : '悬浮歌词已关闭', duration: 1500 })
            })
          Image($r('app.media.ic_lyric'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.text_primary'))
            .onClick(() => {
              void this.importLyric()
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12 })
        .bindSheet($$this.showSourceSheet, this.SourceSheetBuilder(), {
          height: 460,
          dragBar: true,
          backgroundColor: $r('app.color.bg_card'),
          onDisappear: () => {
            this.showSourceSheet = false
          }
        })

        if (this.lyricVisible) {
          // 歌词模式
          Column() {
            Text(this.musicName)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .margin({ top: 6 })
            Row() {
              Text(this.musicSinger)
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.searchingLyric ? '检索中…' : '重新搜索歌词')
                .fontSize(11)
                .fontColor($r('app.color.theme_primary'))
                .padding({ left: 10, top: 2, bottom: 2 })
                .onClick(() => {
                  void this.searchLyric()
                })
            }
            .width('100%')
            .margin({ top: 2, bottom: 6 })
            LyricView({ lines: this.lyricLines })
              .layoutWeight(1)
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          // 封面模式
          Column({ space: 18 }) {
            Stack() {
              Circle()
                .width(220)
                .height(220)
                .fill($r('app.color.bg_card'))
              Circle()
                .width(200)
                .height(200)
                .fill($r('app.color.theme_primary'))
                .opacity(0.9)
              Text('♪')
                .fontSize(72)
                .fontColor(Color.White)
            }
            .margin({ top: 24 })

            Text(this.musicName)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 32, right: 32 })

            Text(this.musicSinger.length > 0 ? this.musicSinger : '未知歌手')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))

            // 暂无歌词时的占位提示：给出「自动检索」与「手动导入」两条明确出路
            Column({ space: 8 }) {
              Text(this.lyricSearchMissed ? '未检索到该歌曲的歌词' : '暂无歌词')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
              Button(this.searchingLyric ? '检索中…' : '搜索歌词')
                .height(34)
                .fontSize(13)
                .type(ButtonType.Capsule)
                .backgroundColor($r('app.color.theme_primary'))
                .fontColor(Color.White)
                .enabled(!this.searchingLyric)
                .onClick(() => {
                  void this.searchLyric()
                })
              Text(this.importingLyric ? '歌词导入中…' : '也可点右上角图标导入 .lrc 文件')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .layoutWeight(1)
        }

        // 进度条
        Column() {
          Slider({
            // 拖拽中用 dragValue，避免 timeUpdate 回写把滑块拽回去
            value: this.dragging
              ? this.dragValue
              : Math.min(this.progressTime, this.maxTime > 0 ? this.maxTime : this.progressTime),
            min: 0,
            max: this.maxTime > 0 ? this.maxTime : 1,
            style: SliderStyle.OutSet
          })
            .selectedColor($r('app.color.theme_primary'))
            .trackColor($r('app.color.divider'))
            .blockColor($r('app.color.theme_primary'))
            .width('92%')
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode == SliderChangeMode.End || mode == SliderChangeMode.Click) {
                this.dragging = false
                this.dragValue = value
                void PlayerFacade.seek(value)
                void PlayerFacade.syncSessionPosition()
              } else {
                // Moving / Begin：进入拖拽态，锁住滑块值
                this.dragging = true
                this.dragValue = value
              }
            })
          Row() {
            Text(formatTime(this.dragging ? this.dragValue : this.progressTime))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
            Blank()
            Text(formatTime(this.maxTime))
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('92%')
        }
        .width('100%')

        // 音量调节
        Row({ space: 8 }) {
          Text(this.playerMuted ? '静音' : '音量')
            .fontSize(12)
            .fontColor(this.playerMuted ? $r('app.color.theme_primary') : $r('app.color.text_secondary'))
            .width(32)
            .onClick(() => {
              PlayerFacade.toggleMute()
            })
          Slider({
            value: this.playerVolume,
            min: 0,
            max: 100,
            style: SliderStyle.OutSet
          })
            .selectedColor($r('app.color.theme_primary'))
            .trackColor($r('app.color.divider'))
            .blockColor($r('app.color.theme_primary'))
            .layoutWeight(1)
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode != SliderChangeMode.End) {
                PlayerFacade.setVolume(value)
              }
            })
          Text(`${Math.round(this.playerVolume)}`)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width(28)
            .textAlign(TextAlign.End)
        }
        .width('92%')
        .padding({ top: 6, bottom: 2 })

        // 系统媒体流被静音时的提示：应用内音量是应用级增益，
        // 系统媒体音量叠加在其上，系统侧为 0 时本应用同样没有声音
        if (this.playerSystemMuted) {
          Text('系统媒体音量已静音，请检查通知面板或控制中心的音量')
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
            .width('92%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        // 播放失败提示与重试
        if (this.playerStatus == 'error') {
          Row({ space: 10 }) {
            Text('播放失败，换个音源或点右侧重试')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Text('重试')
              .fontSize(13)
              .fontColor($r('app.color.theme_primary'))
              .onClick(() => {
                void PlayerFacade.toggle()
              })
          }
          .width('92%')
          .padding({ top: 4, bottom: 4 })
        }

        // 控制区
        Row({ space: 30 }) {
          Image(this.modeIcon(this.playMode))
            .width(22)
            .height(22)
            .fillColor($r('app.color.text_secondary'))
            .onClick(() => {
              void this.switchMode()
            })

          Image($r('app.media.ic_prev'))
            .width(34)
            .height(34)
            .fillColor($r('app.color.text_primary'))
            .onClick(() => {
              void PlayerFacade.skipPrev()
            })

          Image(this.playerStatus == 'playing' ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
            .width(56)
            .height(56)
            .fillColor($r('app.color.theme_primary'))
            .onClick(() => {
              void PlayerFacade.toggle()
            })

          Image($r('app.media.ic_next'))
            .width(34)
            .height(34)
            .fillColor($r('app.color.text_primary'))
            .onClick(() => {
              void PlayerFacade.skipNext()
            })

          // 播放队列（对齐上游 PlayDetail 播放列表按钮）
          Image($r('app.media.ic_queue'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.refreshQueue()
              this.saveMode = false
              this.saveListName = ''
              this.showQueueSheet = true
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 12, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
      .bindSheet($$this.showQueueSheet, this.QueueSheetBuilder(), {
        height: 460,
        dragBar: true,
        backgroundColor: $r('app.color.bg_card'),
        onDisappear: () => {
          this.showQueueSheet = false
          this.saveMode = false
          this.saveListName = ''
        }
      })
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.translate({ y: 800 }).animation({ duration: 260, curve: Curve.EaseOut }))
  }

  @Builder
  QueueSheetBuilder() {
    Column() {
      Row() {
        if (this.saveMode) {
          // 内联输入：歌单名称 + 确定/取消
          TextInput({ placeholder: '输入歌单名称', text: this.saveListName })
            .fontSize(13)
            .layoutWeight(1)
            .height(34)
            .backgroundColor($r('app.color.bg_page'))
            .borderRadius(6)
            .onChange((value: string) => {
              this.saveListName = value
            })
          Text('确定')
            .fontSize(13)
            .fontColor($r('app.color.theme_primary'))
            .padding({ left: 10, right: 2 })
            .onClick(() => {
              void this.confirmSaveQueue()
            })
          Text('取消')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 10, right: 16 })
            .onClick(() => {
              this.saveMode = false
              this.saveListName = ''
            })
        } else {
          Text(`播放队列（${this.queueList.length}）`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
            .padding({ left: 16, top: 10, bottom: 6 })
          if (this.queueList.length > 0) {
            Text('保存为歌单')
              .fontSize(13)
              .fontColor($r('app.color.theme_primary'))
              .padding({ right: 12, top: 10, bottom: 6 })
              .onClick(() => {
                this.saveListName = ''
                this.saveMode = true
              })
            Text('清空')
              .fontSize(13)
              .fontColor($r('app.color.theme_primary'))
              .padding({ right: 16, top: 10, bottom: 6 })
              .onClick(() => {
                this.clearQueue()
              })
          }
        }
      }
      .width('100%')
      if (this.queueList.length == 0) {
        Column({ space: 8 }) {
          Text('队列空').fontSize(14).fontColor($r('app.color.text_secondary'))
          Text('从歌单或搜索结果开始播放后展示队列')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.queueList, (item: MusicInfo, index: number) => {
            ListItem() {
              Row({ space: 8 }) {
                // 当前播放指示
                if (index == this.queueIndex) {
                  Image($r('app.media.ic_pause'))
                    .width(16)
                    .height(16)
                    .fillColor($r('app.color.theme_primary'))
                } else {
                  Text(`${index + 1}`)
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .width(16)
                    .textAlign(TextAlign.Center)
                }
                Column({ space: 2 }) {
                  Text(item.name)
                    .fontSize(14)
                    .fontWeight(index == this.queueIndex ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(index == this.queueIndex
                      ? $r('app.color.theme_primary') : $r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(item.singer.length > 0 ? item.singer : '未知歌手')
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(item.interval != null ? item.interval : '')
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))

                // 队列内重排：上移
                Text('↑')
                  .fontSize(15)
                  .fontColor(index == 0 ? $r('app.color.divider') : $r('app.color.text_secondary'))
                  .width(18)
                  .textAlign(TextAlign.Center)
                  .enabled(index != 0)
                  .onClick(() => {
                    this.moveInQueue(index, index - 1)
                  })

                // 队列内重排：下移
                Text('↓')
                  .fontSize(15)
                  .fontColor(index == this.queueList.length - 1
                    ? $r('app.color.divider') : $r('app.color.text_secondary'))
                  .width(18)
                  .textAlign(TextAlign.Center)
                  .enabled(index != this.queueList.length - 1)
                  .onClick(() => {
                    this.moveInQueue(index, index + 1)
                  })

                Image($r('app.media.ic_delete'))
                  .width(16)
                  .height(16)
                  .fillColor($r('app.color.text_secondary'))
                  .onClick(() => {
                    void PlayerFacade.removeAt(index)
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 9, bottom: 9 })
              .onClick(() => {
                if (item.id != this.currentMusicId) {
                  // 按 id 定位：队列快照可能已过期（增删/重排后），用 index 会播到另一首
                  void PlayerFacade.playById(item.id)
                }
                this.showQueueSheet = false
              })
            }
          }, (item: MusicInfo, index: number) => `${item.id}_${index}_${this.playQueueRev}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SourceSheetBuilder() {
    Column() {
      Text('换源播放')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 2 })
      Text(this.searchKeyword())
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: 16, right: 16, bottom: 6 })

      // 音源选择
      Row({ space: 8 }) {
        ForEach(this.sourceIds, (id: string) => {
          Text(this.sourceLabel(id))
            .fontSize(12)
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .borderRadius(13)
            .backgroundColor(this.candidateSourceId == id ? $r('app.color.theme_primary') : $r('app.color.bg_page'))
            .fontColor(this.candidateSourceId == id ? Color.White : $r('app.color.text_secondary'))
            .onClick(() => {
              void this.searchSource(id)
            })
        }, (id: string) => id)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      if (this.sourceSearching) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(30)
            .height(30)
            .color($r('app.color.theme_primary'))
          Text('正在搜索…')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.candidates.length > 0) {
        List({ space: 2 }) {
          ForEach(this.candidates, (item: MusicInfo) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 2 }) {
                  Text(item.name)
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.candidateSubtitle(item))
                    .fontSize(11)
                    .fontColor($r('app.color.text_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(item.interval != null ? item.interval : '--:--')
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 9, bottom: 9 })
              .borderRadius(8)
              .backgroundColor($r('app.color.bg_page'))
              .onClick(() => {
                void this.applyCandidate(item)
              })
            }
          }, (item: MusicInfo) => `${item.id}_${this.candidateSourceId}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
      } else {
        Column({ space: 8 }) {
          Text(this.sourceSearched ? '未找到匹配歌曲，换个音源试试' : '选择音源，搜索同名歌曲')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          Text('确认候选后将替换当前播放，队列其余歌曲不变')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
