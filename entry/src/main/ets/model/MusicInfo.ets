/**
 * 音乐数据模型 — 对齐上游 lx-music-mobile `src/types/music.d.ts` (LX.Music.MusicInfo)
 * MVP 阶段仅含 local 源；在线源形状在 meta_online 中预留。
 */

export type MusicSource = 'local' | 'kw' | 'wy' | 'kg' | 'tx' | 'mg'

export interface MusicInfoMetaLocal {
  songId: string
  albumName: string
  picUrl?: string | null
  filePath: string
  ext: string
}

export interface MusicInfoMetaOnline {
  songId: string
  albumName: string
  picUrl?: string | null
  albumId?: string
  /** tx 等按 songmid 构造直链 filename 的源：歌曲 mid 与文件 media_mid（其他源无此字段） */
  songmid?: string
  strMediaMid?: string
  /** mg 源专用：版权/内容 id（直链必需）与歌词地址（歌词接口需要） */
  copyrightId?: string
  contentId?: string
  lrcUrl?: string
  mrcUrl?: string
  trcUrl?: string
  qualitys: QualityInfo[]
}

export interface QualityInfo {
  type: string
  size: string | null
  /** kg 等按 hash 取直链的源：该质量对应的文件 hash（其他源无此字段） */
  hash?: string
}

export interface MusicInfo {
  id: string
  name: string
  singer: string
  source: MusicSource
  /** 格式化后的时长，例 "03:55"；本地导入时由元数据生成 */
  interval: string | null
  meta: MusicInfoMetaLocal | MusicInfoMetaOnline
}

export interface LyricInfo {
  lyric: string
  tlyric?: string | null
  rlyric?: string | null
  lxlyric?: string | null
}

export function isLocalInfo(meta: MusicInfoMetaLocal | MusicInfoMetaOnline): boolean {
  return (meta as MusicInfoMetaLocal).filePath != undefined
}

export function toLocalMeta(meta: MusicInfoMetaLocal | MusicInfoMetaOnline): MusicInfoMetaLocal {
  return meta as MusicInfoMetaLocal
}