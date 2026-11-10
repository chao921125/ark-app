/**
 * 按歌曲检索歌词 — 以「当前选中歌曲」为条件跨音源查找歌词
 *
 * 与 LyricManager 的分工：
 *  - LyricManager.loadForMusic：**被动**加载（本地 .lrc 优先，在线源按优先级取），
 *    同一首歌有缓存短路，且本地导入的歌不参与在线检索；
 *  - LyricSearch.search：**主动**检索，用户显式触发时强制重新查找，
 *    且本地导入的歌（没有源内 songId）会用「歌名 + 歌手」反查同名歌曲再取歌词。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MusicInfo, isLocalInfo } from '../model/MusicInfo'
import { LyricParser, LyricLine, isPlaceholderLyric } from './LyricParser'
import { SourceResolver } from '../core/source/SourceResolver'

const TAG = 'LyricSearch'
const DOMAIN = 0x0001

/** 检索结果 */
export interface LyricSearchResult {
  /** 解析出的歌词行（无歌词时为空数组） */
  lines: LyricLine[]
  /** 命中的音源 id（未命中为 ''） */
  sourceId: string
  /** 是否检索到歌词 */
  found: boolean
}

/** 歌名归一化：去掉括号后缀与空白，用于宽松匹配（如「花海 (DJ 阿若版)」↔「花海」） */
function normalizeName(name: string): string {
  let s = name.trim().toLowerCase()
  const paren = s.indexOf('(')
  if (paren > 0) {
    s = s.substring(0, paren)
  }
  const bracket = s.indexOf('[')
  if (bracket > 0) {
    s = s.substring(0, bracket)
  }
  return s.replace(/\s+/g, '')
}

/** 歌手是否匹配（宽松：一方包含另一方即可；任一方为空则视为匹配） */
function singerMatches(a: string, b: string): boolean {
  if (a.length === 0 || b.length === 0) {
    return true
  }
  const na = a.replace(/\s+/g, '').toLowerCase()
  const nb = b.replace(/\s+/g, '').toLowerCase()
  return na.indexOf(nb) >= 0 || nb.indexOf(na) >= 0
}

class LyricSearchImpl {
  /**
   * 按歌曲检索歌词。
   * 依次尝试：歌曲自身所在音源 → 用歌名+歌手在各音源反查同名歌曲。
   */
  async search(music: MusicInfo | undefined): Promise<LyricSearchResult> {
    const empty: LyricSearchResult = { lines: [], sourceId: '', found: false }
    if (music == undefined) {
      return empty
    }
    const resolver: SourceResolver = SourceResolver.getInstance()
    const priority: string[] = resolver.getPriority()

    // ① 歌曲本身就是某音源的在线歌曲 → 直接向该源取歌词
    if (!isLocalInfo(music.meta)) {
      try {
        const text: string = await resolver.getLyricFrom(music.source, music)
        if (text.length > 0 && !isPlaceholderLyric(text)) {
          const lines: LyricLine[] = LyricParser.parse(text)
          if (lines.length > 0) {
            hilog.info(DOMAIN, TAG, 'lyric searched from own source: %{public}s', music.source)
            return { lines: lines, sourceId: music.source, found: true }
          }
        }
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'own source %{public}s lyric failed: %{public}s', music.source, JSON.stringify(e))
      }
    }

    // ② 用「歌名」在各音源反查同名歌曲，再用其 meta 取歌词
    //    （本地导入的歌没有源内 songId，只能这样反查）
    const targetName: string = normalizeName(music.name)
    if (targetName.length === 0) {
      return empty
    }
    for (let i = 0; i < priority.length; i++) {
      const sourceId: string = priority[i]
      try {
        const candidates: MusicInfo[] = await resolver.search(sourceId, music.name)
        for (let j = 0; j < candidates.length; j++) {
          const cand: MusicInfo = candidates[j]
          if (normalizeName(cand.name) != targetName) {
            continue
          }
          if (!singerMatches(cand.singer, music.singer)) {
            continue
          }
          const text: string = await resolver.getLyricFrom(sourceId, cand)
          if (text.length === 0 || isPlaceholderLyric(text)) {
            continue
          }
          const lines: LyricLine[] = LyricParser.parse(text)
          if (lines.length > 0) {
            hilog.info(DOMAIN, TAG, 'lyric searched by name: source=%{public}s lines=%{public}d', sourceId, lines.length)
            return { lines: lines, sourceId: sourceId, found: true }
          }
        }
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'source %{public}s search lyric failed: %{public}s', sourceId, JSON.stringify(e))
      }
    }

    hilog.info(DOMAIN, TAG, 'lyric not found for: %{public}s', music.name)
    return empty
  }
}

export const LyricSearch: LyricSearchImpl = new LyricSearchImpl()
