/**
 * 迷你播放条 — 对齐上游 `src/components/player/PlayerBar`
 */
import { MusicInfo } from '../model/MusicInfo'
import { PlayerFacade } from '../app/PlayerFacade'

@Component
export struct PlayerBar {
  @StorageLink('currentMusicJson') @Watch('onMusicChange') currentMusicJson: string = ''
  @StorageLink('playerStatus') playerStatus: string = 'idle'
  @State musicName: string = ''
  @State musicSinger: string = ''

  onMusicChange(): void {
    if (this.currentMusicJson.length == 0) {
      this.musicName = ''
      this.musicSinger = ''
      return
    }
    try {
      const m = JSON.parse(this.currentMusicJson) as MusicInfo
      this.musicName = m.name
      this.musicSinger = m.singer
    } catch (e) {
      this.musicName = ''
      this.musicSinger = ''
    }
  }

  build() {
    if (this.currentMusicJson.length == 0) {
      Column()
        .width('100%')
        .height(0)
    } else {
      Row({ space: 12 }) {
        Stack() {
          Circle()
            .width(40)
            .height(40)
            .fill($r('app.color.theme_primary'))
          Text('♪')
            .fontSize(18)
            .fontColor(Color.White)
        }
        .onClick(() => {
          AppStorage.setOrCreate<boolean>('showPlayDetail', true)
        })

        Column({ space: 2 }) {
          Text(this.musicName)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.musicSinger)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .onClick(() => {
          AppStorage.setOrCreate<boolean>('showPlayDetail', true)
        })

        Image(this.playerStatus == 'playing' ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
          .width(24)
          .height(24)
          .fillColor($r('app.color.text_primary'))
          .onClick(() => {
            void PlayerFacade.toggle()
          })
      }
      .width('100%')
      .padding({ left: 12, right: 16 })
      .height(56)
      .backgroundColor($r('app.color.bg_card'))
      .borderRadius({ topLeft: 12, topRight: 12 })
    }
  }
}
