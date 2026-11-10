/**
 * 歌单数据模型 — 对齐上游 `src/core/list.ts` 的“我的列表”机制（简化版）
 * 上游使用 KV 存储 JSON 序列化的列表集合，此处保持一致。
 */
import { MusicInfo } from './MusicInfo'

export interface SongList {
  id: string
  name: string
  list: MusicInfo[]
  /** 列表位置更新时间（对齐上游 positionUpdateTime，用于排序） */
  positionUpdateTime: number | null
}

export const DEFAULT_LIST_ID = 'default'
/** 默认列表即"喜欢的音乐"（对齐上游 myDefaultListName 机制：收藏 = 加入 default 列表） */
export const DEFAULT_LIST_NAME = '喜欢的音乐'

/**
 * 内置「本地音乐」列表：存放用户导入到本机的音频。
 * 与「喜欢的音乐」并列，同样是固定内置项（不可重命名、不可删除、不参与 PC 同步）。
 */
export const LOCAL_LIST_ID = 'local_music'
export const LOCAL_LIST_NAME = '本地音乐'

/** 全部内置歌单 id（不参与用户歌单的增删改与排序） */
export const BUILTIN_LIST_IDS: string[] = [DEFAULT_LIST_ID, LOCAL_LIST_ID]

/** 是否为内置歌单 */
export function isBuiltinList(id: string): boolean {
  return BUILTIN_LIST_IDS.includes(id)
}

export function newList(id: string, name: string): SongList {
  let l: SongList = {
    id: id,
    name: name,
    list: [],
    positionUpdateTime: null
  }
  return l
}