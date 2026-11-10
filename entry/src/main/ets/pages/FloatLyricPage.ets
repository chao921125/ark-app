/**
 * 桌面歌词悬浮窗页面（三期）— 由 FloatLyricWindow 通过 setUIContent 加载
 * 展示当前歌词行（与播放详情/应用内歌词条共享 LyricManager 缓存与 AppStorage 进度）；
 * 支持拖动移动悬浮窗（PanGesture → window.moveTo）、点击关闭（回落应用内条）、
 * 点击歌词展开播放详情。
 */

import { promptAction } from '@kit.ArkUI'
import { MusicInfo } from '../model/MusicInfo'
import { LyricManager } from '../lyric/LyricManager'
import { LyricLine, LyricParser } from '../lyric/LyricParser'
import { FloatLyricWindow } from '../lyric/FloatLyricWindow'
import { ListStore } from '../store/ListStore'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG: string = 'FloatLyricPage'
const DOMAIN: number = 0x0001

@Entry
@Component
struct FloatLyricPage {
  @StorageLink('currentMusicJson') @Watch('onMusicChange') currentMusicJson: string = ''
  @StorageLink('progressTime') @Watch('onProgress') progressTime: number = 0
  @State lineText: string = ''
  @State winX: number = 0
  @State winY: number = 0
  private lines: LyricLine[] = []
  private curMusicId: string = ''
  private lastX: number = 0
  private lastY: number = 0
  private moved: boolean = false

  aboutToAppear(): void {
    // 初始化拖动基准坐标为窗口当前位置（避免首次拖动跳位）
    try {
      const w = FloatLyricWindow.findWindow()
      if (w != undefined) {
        const rect = w.getWindowProperties().windowRect
        this.winX = rect.left
        this.winY = rect.top
      }
    } catch (ignored) {
      // 属性获取失败保持 0 基准
    }
    // 页面挂载可能晚于切歌，主动同步一次当前曲与歌词
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

  private async closeWindow(): Promise<void> {
    try {
      await ListStore.setShowFloatLyric(false)
      promptAction.showToast({ message: '桌面歌词已关闭', duration: 1500 })
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'close float lyric window failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '关闭失败，请重试', duration: 1800 })
    }
  }

  private async moveTo(x: number, y: number): Promise<void> {
    const w = FloatLyricWindow.findWindow()
    if (w == undefined) {
      return
    }
    try {
      await w.moveTo(x, y)
      this.winX = x
      this.winY = y
    } catch (ignored) {
      // 移动失败静默忽略（窗口可能已被销毁）
    }
  }

  build() {
    Row({ space: 8 }) {
      Text('♪')
        .fontSize(14)
        .fontColor('#6FDFC3')

      Text(this.lineText.length > 0 ? this.lineText : '暂无歌词')
        .fontSize(15)
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
          void this.closeWindow()
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 8 })
    .backgroundColor('#BF000000')
    .borderRadius(20)
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 8, color: 'rgba(0,0,0,0.25)', offsetX: 0, offsetY: 2 })
    .gesture(
      PanGesture({ fingers: 1, distance: 5 })
        .onActionStart((event: GestureEvent) => {
          this.lastX = this.winX
          this.lastY = this.winY
          this.moved = false
        })
        .onActionUpdate((event: GestureEvent) => {
          if (Math.abs(event.offsetX) > 2 || Math.abs(event.offsetY) > 2) {
            this.moved = true
          }
          void this.moveTo(this.lastX + event.offsetX, this.lastY + event.offsetY)
        })
    )
  }
}