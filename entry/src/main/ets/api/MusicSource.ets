/**
 * 音源抽象 — 对齐上游 `src/core/apiSource.ts`
 * 内置音源提供搜索、播放链接、歌词；自定义音源引擎 SourceEngine 优先，内置源兜底。
 */
import { MusicInfo } from '../model/MusicInfo'
import { LyricInfo } from '../model/MusicInfo'

export interface SourceAdapter {
  readonly id: string
  search(keyword: string): Promise<MusicInfo[]>
  getMusicUrl(music: MusicInfo, quality: string): Promise<string>
  getLyric(music: MusicInfo): Promise<LyricInfo>
  /**
   * 搜索联想（tip search）：按输入前缀返回候选词。
   * 对齐 lx-music-desktop `src/renderer/utils/musicSdk/<源>/tipSearch.js`。
   * 失败时抛错由上层降级处理。
   */
  suggest(keyword: string): Promise<string[]>
}

class SourceRegistryImpl {
  private sources: Map<string, SourceAdapter> = new Map()

  register(adapter: SourceAdapter): void {
    this.sources.set(adapter.id, adapter)
  }

  get(id: string): SourceAdapter | undefined {
    return this.sources.get(id)
  }

  all(): SourceAdapter[] {
    return Array.from(this.sources.values())
  }
}

/** 音源注册中心（内置搜索源在此注册；换源搜索/搜索页使用） */
export const SourceRegistry: SourceRegistryImpl = new SourceRegistryImpl()
