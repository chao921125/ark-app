/**
 * 歌曲信息徽标 — 音质与来源
 *
 * 对齐上游 lx-music-mobile 的 OnlineList/ListItem：
 *  - 副标题行前置音质徽标：flac24bit→「无损24」、flac/ape→「无损」、320k→「高品」，
 *    128k 及以下不标（上游同样不显示）；
 *  - 聚合搜索时再前置来源徽标（单源搜索整页同源，显示是冗余）；
 *  - 徽标样式沿用上游：**纯文字小标签**（无底色），只靠颜色区分档位。
 */
import { MusicInfo, MusicInfoMetaOnline, isLocalInfo } from '../model/MusicInfo'
import { topQuality, qualityBadgeText, qualityLevel, QualityLevel } from '../core/source/MusicMatch'
import { sourceName } from '../model/SourceNames'

@Component
export struct MusicBadges {
  /** 歌曲信息（取 meta.qualitys 与 source） */
  @Prop music: MusicInfo = {} as MusicInfo
  /** 是否显示来源徽标 */
  @Prop showSource: boolean = false

  /** 最高音质档位（本地歌曲无音质，返回空串） */
  private quality(): string {
    if (isLocalInfo(this.music.meta)) {
      return ''
    }
    const meta: MusicInfoMetaOnline = this.music.meta as MusicInfoMetaOnline
    if (meta.qualitys == undefined) {
      return ''
    }
    const types: string[] = []
    for (let i = 0; i < meta.qualitys.length; i++) {
      types.push(meta.qualitys[i].type)
    }
    return topQuality(types)
  }

  /** 音质徽标配色：高档位醒目，低档位弱化 */
  private qualityColor(): ResourceStr {
    const level: QualityLevel = qualityLevel(this.quality())
    if (level == 'lossless24' || level == 'lossless') {
      return $r('app.color.theme_primary')
    }
    if (level == 'high') {
      return '#E8A33D'
    }
    return $r('app.color.text_secondary')
  }

  build() {
    Row({ space: 8 }) {
      Text(qualityBadgeText(this.quality()))
        .fontSize(10)
        .fontColor(this.qualityColor())
      if (this.showSource) {
        Text(sourceName(this.music.source))
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .alignItems(VerticalAlign.Center)
  }
}
