/**
 * 统一音源入口 — 播放域与歌词域访问音源的**唯一**通道
 *
 * 职责边界：把「洛雪自定义源脚本（ArkWeb 沙箱）」与「五个内置在线源」收敛成
 * 一套对上层一致的接口：按 sourceId 取直链 / 取歌词 / 搜索。
 *
 * 为什么要有这一层：
 *   1. PlayerKernel 与 LyricManager 此前各自写了一份音源候选链遍历逻辑，
 *      两份逻辑会随音源能力演进而走偏；
 *   2. 只有这里需要知道「custom 走沙箱、其余走内置适配器」这个二分，
 *      上层不必再同时依赖 SourceEngine 与 SourceRegistry。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MusicInfo, MusicInfoMetaOnline, isLocalInfo } from '../../model/MusicInfo'
import { songMatchKey, pickBetter } from './MusicMatch'
import { SourceRegistry } from '../../api/MusicSource'
import { SourceEngine } from './SourceEngine'
import { LxQuality } from './LxTypes'

const TAG: string = 'SourceResolver'
const DOMAIN: number = 0x0001

/** 自定义音源脚本的 sourceId（对应上游 LX.USER_API） */
export const CUSTOM_SOURCE_ID: string = 'custom'

/** 默认音源优先级链 */
const DEFAULT_PRIORITY: string[] = ['custom', 'kw', 'wy', 'kg', 'tx', 'mg']

export class SourceResolver {
  private static instance: SourceResolver | null = null
  /** 音源优先级链：播放与歌词共用同一份，避免两处逻辑走偏 */
  private priority: string[] = DEFAULT_PRIORITY.slice()

  static getInstance(): SourceResolver {
    if (SourceResolver.instance === null) {
      SourceResolver.instance = new SourceResolver()
    }
    return SourceResolver.instance
  }

  /** 设置音源优先级链（由编排层从设置项同步进来） */
  setPriority(priority: string[]): void {
    if (priority.length === 0) {
      this.priority = DEFAULT_PRIORITY.slice()
      return
    }
    this.priority = priority.slice()
  }

  /** 当前音源优先级链 */
  getPriority(): string[] {
    return this.priority
  }

  /**
   * 构造候选源顺序：单曲覆盖优先，其次按用户配置的优先级链（去重）。
   */
  buildCandidates(music: MusicInfo, priority: string[], overrideSourceId: string | undefined): string[] {
    const candidates: string[] = []
    if (overrideSourceId != undefined && overrideSourceId.length > 0) {
      candidates.push(overrideSourceId)
    }
    for (let i = 0; i < priority.length; i++) {
      if (candidates.indexOf(priority[i]) < 0) {
        candidates.push(priority[i])
      }
    }
    // 兜底：候选链里没写 custom，但用户确实装了自定义源时也允许尝试
    if (candidates.indexOf(CUSTOM_SOURCE_ID) < 0 && this.isCustomReady()) {
      candidates.push(CUSTOM_SOURCE_ID)
    }
    return candidates
  }

  /** 自定义音源脚本是否已加载并就绪 */
  isCustomReady(): boolean {
    const engine: SourceEngine = SourceEngine.getInstance()
    return engine.isInited()
  }

  /** 某个 sourceId 是否可用（自定义源已就绪 / 内置源已注册） */
  isSourceReady(sourceId: string): boolean {
    if (sourceId === CUSTOM_SOURCE_ID) {
      return this.isCustomReady()
    }
    return SourceRegistry.get(sourceId) != undefined
  }

  /**
   * 从**单个**音源取播放直链。失败一律抛异常，由上层决定是否降级到下一个源。
   */
  async getMusicUrlFrom(sourceId: string, music: MusicInfo, quality: string): Promise<string> {
    if (sourceId === CUSTOM_SOURCE_ID) {
      const engine: SourceEngine = SourceEngine.getInstance()
      if (!engine.isInited()) {
        throw new Error('自定义音源未加载')
      }
      if (!engine.supportsAction(music.source, 'musicUrl')) {
        throw new Error(`自定义音源不支持 ${music.source} 的 musicUrl`)
      }
      const url: string = await engine.getMusicUrl(JSON.stringify(music), quality as LxQuality, music.source)
      if (url.length === 0) {
        throw new Error('自定义音源未返回播放链接')
      }
      return url
    }
    const adapter = SourceRegistry.get(sourceId)
    if (adapter == undefined) {
      throw new Error(`音源未注册：${sourceId}`)
    }
    const url: string = await adapter.getMusicUrl(music, quality)
    if (url.length === 0) {
      throw new Error(`音源 ${sourceId} 未返回播放链接`)
    }
    return url
  }

  /**
   * 从**单个**音源取歌词正文（纯文本，不含格式信息）。
   * 取不到时抛异常，由上层决定是否降级到下一个源。
   */
  async getLyricFrom(sourceId: string, music: MusicInfo): Promise<string> {
    if (sourceId === CUSTOM_SOURCE_ID) {
      const engine: SourceEngine = SourceEngine.getInstance()
      if (!engine.isInited()) {
        throw new Error('自定义音源未加载')
      }
      if (!engine.supportsAction(music.source, 'lyric')) {
        throw new Error(`自定义音源不支持 ${music.source} 的 lyric`)
      }
      const lyricJson: string = await engine.getLyric(JSON.stringify(music), music.source)
      return SourceResolver.extractLyricText(lyricJson)
    }
    const adapter = SourceRegistry.get(sourceId)
    if (adapter == undefined) {
      throw new Error(`音源未注册：${sourceId}`)
    }
    const lyricInfo = await adapter.getLyric(music)
    if (lyricInfo == undefined || lyricInfo.lyric == undefined || lyricInfo.lyric.length === 0) {
      throw new Error(`音源 ${sourceId} 未返回歌词`)
    }
    return lyricInfo.lyric
  }

  /**
   * 搜索联想（tip search）：按输入前缀向指定音源取候选词。
   * 对齐 lx-music-desktop 的 tipSearch 能力。
   */
  async suggest(sourceId: string, keyword: string): Promise<string[]> {
    const adapter = SourceRegistry.get(sourceId)
    if (adapter == undefined) {
      throw new Error(`音源未注册：${sourceId}`)
    }
    return adapter.suggest(keyword)
  }

  /**
   * 聚合联想：并行查询多个音源的 tip search，合并去重。
   * 单个音源失败不影响整体。
   */
  async suggestAll(keyword: string, sourceIds: string[]): Promise<string[]> {
    const kw = keyword.trim()
    if (kw.length === 0 || sourceIds.length === 0) {
      return []
    }
    const perSource: string[][] = await Promise.all(sourceIds.map(async (id: string): Promise<string[]> => {
      try {
        return await this.suggest(id, kw)
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'aggregate suggest source %{public}s failed: %{public}s', id, JSON.stringify(e))
        return []
      }
    }))
    const merged: string[] = []
    const seen: Set<string> = new Set()
    for (let i = 0; i < perSource.length; i++) {
      const list: string[] = perSource[i]
      for (let j = 0; j < list.length; j++) {
        const word: string = list[j]
        if (word.length === 0 || seen.has(word)) {
          continue
        }
        seen.add(word)
        merged.push(word)
      }
    }
    return merged
  }

  /**
   * 可用于搜索的音源 id 列表（聚合搜索用）。
   * 只包含已注册的**内置音源**（自定义脚本走 SourceEngine，不在此列）。
   */
  getSearchableSources(): string[] {
    const ids: string[] = []
    const adapters = SourceRegistry.all()
    for (let i = 0; i < adapters.length; i++) {
      ids.push(adapters[i].id)
    }
    return ids
  }

  /** 在指定音源里搜索 */
  async search(sourceId: string, keyword: string): Promise<MusicInfo[]> {
    const adapter = SourceRegistry.get(sourceId)
    if (adapter == undefined) {
      throw new Error(`音源未注册：${sourceId}`)
    }
    return adapter.search(keyword)
  }

  /**
   * 聚合搜索：并行查询多个音源并合并去重。
   *
   * 去重规则（对齐上游 lx-music-desktop 的 findMusic 思路）：
   *  - 歌名/歌手归一化后相同即视为同一首歌；
   *  - 同一首在多个源的结果合并为一条，保留**音质更高**的那条。
   *
   * 单个音源失败不影响整体（该源贡献 0 条）。
   */
  async searchAll(keyword: string, sourceIds: string[]): Promise<MusicInfo[]> {
    const kw = keyword.trim()
    if (kw.length === 0 || sourceIds.length === 0) {
      return []
    }
    const perSource: MusicInfo[][] = await Promise.all(sourceIds.map(async (id: string): Promise<MusicInfo[]> => {
      try {
        return await this.search(id, kw)
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'aggregate search source %{public}s failed: %{public}s', id, JSON.stringify(e))
        return []
      }
    }))
    const merged: MusicInfo[] = []
    const indexByKey: Map<string, number> = new Map()
    for (let i = 0; i < perSource.length; i++) {
      const list: MusicInfo[] = perSource[i]
      for (let j = 0; j < list.length; j++) {
        const music: MusicInfo = list[j]
        const key: string = songMatchKey(music.name, music.singer)
        const at: number | undefined = indexByKey.get(key)
        if (at == undefined) {
          indexByKey.set(key, merged.length)
          merged.push(music)
          continue
        }
        // 同一首歌：保留音质更高的
        const keepIncoming: boolean = pickBetter(
          { qualitys: SourceResolver.qualityTypes(merged[at]) },
          { qualitys: SourceResolver.qualityTypes(music) }
        )
        if (keepIncoming) {
          merged[at] = music
        }
      }
    }
    return merged
  }

  /** 取一条歌曲可用音质列表（在线源才有 qualitys） */
  private static qualityTypes(music: MusicInfo): string[] {
    if (isLocalInfo(music.meta)) {
      return []
    }
    const meta: MusicInfoMetaOnline = music.meta as MusicInfoMetaOnline
    const list: string[] = []
    if (meta.qualitys != undefined) {
      for (let i = 0; i < meta.qualitys.length; i++) {
        list.push(meta.qualitys[i].type)
      }
    }
    return list
  }

  /**
   * 沙箱返回的歌词是 result.data 的 JSON 文本，里面可能是裸字符串，
   * 也可能是 { lyric, tlyric, rlyric, lxlyric } 结构 —— 两种都要兜住。
   */
  private static extractLyricText(lyricJson: string): string {
    let text: string = lyricJson
    try {
      const parsed = JSON.parse(lyricJson) as Object
      if (typeof parsed === 'string') {
        text = parsed as string
      } else {
        const rec = parsed as Record<string, Object>
        if (typeof rec['lyric'] === 'string') {
          text = rec['lyric'] as string
        }
      }
    } catch (ignored) {
      // 不是 JSON，按裸文本处理
    }
    if (text.length === 0) {
      throw new Error('自定义音源未返回歌词')
    }
    return text
  }
}
