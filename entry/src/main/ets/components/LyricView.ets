/**
 * 歌词滚动组件 — 对齐上游 PlayDetail 的 Lyric 组件（简化）
 * 按播放进度自动滚动并高亮当前行。
 */
import { LyricLine, LyricParser } from '../lyric/LyricParser'

@Component
export struct LyricView {
  @Prop @Watch('onLinesChange') lines: LyricLine[] = []
  @StorageLink('progressTime') @Watch('onProgress') progressTime: number = 0
  @StorageLink('lyricFontSize') lyricFontSize: number = 16
  @State curIndex: number = -1
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.curIndex = LyricParser.findLineIndex(this.lines, this.progressTime * 1000)
  }

  onLinesChange(): void {
    this.curIndex = LyricParser.findLineIndex(this.lines, this.progressTime * 1000)
    this.scrollToLine(this.curIndex)
  }

  onProgress(): void {
    const idx = LyricParser.findLineIndex(this.lines, this.progressTime * 1000)
    if (idx != this.curIndex) {
      this.curIndex = idx
      this.scrollToLine(idx)
    }
  }

  private scrollToLine(idx: number): void {
    if (idx < 0) {
      return
    }
    // 行高按 字号 + 间距 + 换行行高估计，粗略滚动到视口 1/3 处
    const lineH = this.estimateLineHeight(idx)
    const offset = lineH - 120
    if (offset > 0) {
      this.scroller.scrollTo({ xOffset: 0, yOffset: offset, animation: true })
    } else {
      this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: true })
    }
  }

  private estimateLineHeight(targetIdx: number): number {
    let h = 0
    for (let i = 0; i < targetIdx && i < this.lines.length; i++) {
      const wrapCount = this.lines[i].text.split('\n').length
      h += (this.lyricFontSize + 14) * wrapCount + 8
    }
    return h
  }

  build() {
    if (this.lines.length == 0) {
      Column() {
        Text('暂无歌词')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      Scroll(this.scroller) {
        Column({ space: 10 }) {
          ForEach(this.lines, (line: LyricLine, idx: number) => {
            Text(line.text)
              .fontSize(this.lyricFontSize)
              .lineHeight(this.lyricFontSize + 8)
              .fontColor(idx == this.curIndex ? $r('app.color.theme_primary') : $r('app.color.text_secondary'))
              .fontWeight(idx == this.curIndex ? FontWeight.Bold : FontWeight.Normal)
              .textAlign(TextAlign.Center)
              .width('100%')
          }, (line: LyricLine, idx: number) => `${idx}_${line.time}`)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 120, bottom: 300 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
    }
  }
}