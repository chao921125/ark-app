/**
 * 歌曲行组件 — 对齐上游 `src/screens/Home/Views/Mylist/MusicList/index.tsx`（简化）
 */
import { MusicInfo, MusicInfoMetaOnline } from '../model/MusicInfo'
import { MusicBadges } from './MusicBadges'

@Component
export struct MusicListItem {
  @Prop music: MusicInfo = {
    id: '',
    name: '',
    singer: '',
    source: 'local',
    interval: null,
    meta: {
      songId: '',
      albumName: '',
      picUrl: null,
      filePath: '',
      ext: ''
    }
  }
  @Prop active: boolean = false
  @Prop liked: boolean = false
  /** 是否显示歌曲时长（对齐上游 list.isShowInterval） */
  @Prop showInterval: boolean = true
  /** 是否显示歌曲专辑名（对齐上游 list.isShowAlbumName） */
  @Prop showAlbumName: boolean = false
  onPlay: () => void = () => {}
  onRemove: () => void = () => {}
  onToggleLike: () => void = () => {}

  /** 副标题：歌手；开启专辑名且有专辑时追加「· 专辑」 */
  private subtitle(): string {
    const singer: string = this.music.singer.length > 0 ? this.music.singer : '未知歌手'
    if (!this.showAlbumName) {
      return singer
    }
    const album: string = this.albumName()
    if (album.length === 0) {
      return singer
    }
    return `${singer} · ${album}`
  }

  /** 专辑名：在线源在 meta.albumName，本地源无此字段 */
  private albumName(): string {
    const meta = this.music.meta as MusicInfoMetaOnline
    const album = meta.albumName
    return typeof album == 'string' ? album : ''
  }

  build() {
    Row({ space: 12 }) {
      // 序号 / 播放指示
      Text(this.active ? '♪' : '')
        .fontSize(16)
        .fontColor($r('app.color.theme_primary'))
        .fontWeight(FontWeight.Medium)
        .width(28)
        .textAlign(TextAlign.Center)

      Column({ space: 3 }) {
        Text(this.music.name)
          .fontSize(16)
          .fontColor(this.active ? $r('app.color.theme_primary') : $r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        // 副标题行：音质/来源徽标 + 歌手·专辑（对齐上游 OnlineList/ListItem）
        Row({ space: 8 }) {
          MusicBadges({ music: this.music, showSource: true })
          Text(this.subtitle())
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      // 【坑】播放触发必须用 onClick，不能用 gesture(TapGesture())：
      // 本组件被放在带 swipeAction（侧滑删除）的 ListItem 里，通用手势会与
      // List 的滚动/滑动手势竞争，点击被 List 吞掉 → 点了歌名毫无反应，
      // 播放器仍在放上一首，看起来就是「点 A 播 B」。
      // onClick 是 ClickEvent，与 List 的手势竞争解耦。
      // 放在歌名区域而非整行：♥ 是同一行的兄弟节点，ClickEvent 会冒泡，
      // 若整行都监听 onClick，点 ♥ 收藏会连带触发播放。
      .onClick(() => {
        this.onPlay()
      })

      // 收藏爱心（对齐上游 likeList：点亮表示已在"喜欢的音乐"）
      // 【区分】已收藏 = 实心红心，未收藏 = 空心灰心（用 text_secondary，
      // divider 色太浅会让人分辨不出收藏状态）
      Text(this.liked ? '♥' : '♡')
        .fontSize(18)
        .fontColor(this.liked ? '#E05454' : $r('app.color.text_secondary'))
        .onClick(() => {
          this.onToggleLike()
        })

      if (this.showInterval) {
        Text(this.music.interval ?? '--:--')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .padding({ left: 8, right: 16, top: 10, bottom: 10 })
    .borderRadius(8)
    .backgroundColor(this.active ? $r('app.color.bg_card') : Color.Transparent)
  }
}
