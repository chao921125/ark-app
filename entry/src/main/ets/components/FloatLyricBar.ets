/**
 * 悬浮歌词条 — 应用内"桌面歌词"（三期，双模式回落）
 * 覆盖在主界面之上的可拖动歌词条：同步显示当前歌词行，点击展开播放详情，可随时关闭。
 * 真全局悬浮窗（FloatLyricWindow，需 SYSTEM_FLOAT_WINDOW）可用时本组件自动隐藏
 * （floatLyricWindowActive=true 互斥）；否则作为应用内回落方案展示。
 */
import { display } from '@kit.ArkUI'
import { MusicInfo } from '../model/MusicInfo'
import { LyricManager } from '../lyric/LyricManager'
import { LyricLine, LyricParser } from '../lyric/LyricParser'
import { ListStore } from '../store/ListStore'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG: string = 'FloatLyricBar'
const DOMAIN: number = 0x0001

/** 拖动边界（vp），按实际屏幕尺寸计算 */
interface BarBounds {
  maxX: number
  maxY: number
}

@Component
export struct FloatLyricBar {
  @StorageLink('showFloatLyric') show: boolean = false
  @StorageLink('floatLyricWindowActive') windowActive: boolean = false
  @StorageLink('currentMusicJson') @Watch('onMusicChange') currentMusicJson: string = ''
  @StorageLink('progressTime') @Watch('onProgress') progressTime: number = 0
  @State lineText: string = ''
  @State barX: number = 24
  @State barY: number = 88
  private lines: LyricLine[] = []
  private curMusicId: string = ''
  private lastX: number = 0
  private lastY: number = 0

  aboutToAppear(): void {
    // 组件挂载可能晚于快照恢复（currentMusicJson 已就位），主动同步一次
    this.onMusicChange()
  }

  onMusicChange(): void {
    let music: MusicInfo | undefined = undefined
    if (this.currentMusicJson.length > 0) {
      try {
        music = JSON.parse(this.currentMusicJson) as MusicInfo
      } catch (ignored) {
        music = undefined
      }
    }
    if (music == undefined) {
      this.lines = []
      this.curMusicId = ''
      this.lineText = ''
      return
    }
    if (music.id == this.curMusicId) {
      return
    }
    this.curMusicId = music.id
    void this.loadLines(music)
  }

  private async loadLines(music: MusicInfo): Promise<void> {
    // LyricManager 按 id 缓存，与播放详情页共享同一份歌词
    let lines: LyricLine[] = []
    try {
      lines = await LyricManager.loadForMusic(music)
    } catch (e) {
      // 歌词加载失败只降级为「无歌词」，不影响悬浮歌词条本身
      hilog.warn(DOMAIN, TAG, 'load lyric lines failed: %{public}s', JSON.stringify(e))
    }
    if (music.id != this.curMusicId) {
      return
    }
    this.lines = lines
    this.refreshLine()
  }

  onProgress(): void {
    this.refreshLine()
  }

  private refreshLine(): void {
    if (this.lines.length == 0) {
      return
    }
    const idx = LyricParser.findLineIndex(this.lines, this.progressTime * 1000)
    let text = idx >= 0 ? this.lines[idx].text : ''
    const nl = text.indexOf('\n')
    if (nl >= 0) {
      text = text.substring(0, nl)
    }
    if (text != this.lineText) {
      this.lineText = text
    }
  }

  build() {
    if (this.show && !this.windowActive && this.currentMusicJson.length > 0) {
      Row({ space: 8 }) {
        Text('♪')
          .fontSize(14)
          .fontColor('#6FDFC3')

        Text(this.lineText.length > 0 ? this.lineText : '暂无歌词')
          .fontSize(14)
          .fontColor(Color.White)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .onClick(() => {
            AppStorage.setOrCreate<boolean>('showPlayDetail', true)
          })

        Text('✕')
          .fontSize(13)
          .fontColor('#B3FFFFFF')
          .padding(4)
          .onClick(() => {
            void ListStore.setShowFloatLyric(false)
          })
      }
      .width('86%')
      .height(40)
      .padding({ left: 12, right: 8 })
      .backgroundColor('#BF000000')
      .borderRadius(20)
      .alignItems(VerticalAlign.Center)
      .position({ x: this.barX, y: this.barY })
      .shadow({ radius: 8, color: 'rgba(0,0,0,0.25)', offsetX: 0, offsetY: 2 })
      .gesture(
        PanGesture({ fingers: 1, distance: 5 })
          .onActionStart(() => {
            this.lastX = this.barX
            this.lastY = this.barY
          })
          .onActionUpdate((event: GestureEvent) => {
            const nx = this.lastX + event.offsetX
            const ny = this.lastY + event.offsetY
            const bounds = this.dragBounds()
            this.barX = Math.min(Math.max(nx, 8), bounds.maxX)
            this.barY = Math.min(Math.max(ny, 56), bounds.maxY)
          })
      )
    }
  }

  /** 歌词条宽 86%，横向可滑动余量小；纵向在屏幕内自由拖动 */
  private dragBounds(): BarBounds {
    try {
      const d = display.getDefaultDisplaySync()
      const density = d.densityPixels > 0 ? d.densityPixels : 3
      const wVp = d.width / density
      const hVp = d.height / density
      return { maxX: Math.max(wVp * 0.14 - 8, 8), maxY: Math.max(hVp - 120, 200) }
    } catch (ignored) {
      return { maxX: 50, maxY: 700 }
    }
  }
}
