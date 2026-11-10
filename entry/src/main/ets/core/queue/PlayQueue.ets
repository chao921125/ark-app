/**
 * 播放队列 — 播放域的纯逻辑容器（无 IO、无平台 API）
 *
 * 职责边界：只管「队列里有哪些歌、当前在哪一首、增删改排之后索引怎么修正」。
 * 不碰 AVPlayer、不碰音源、不碰持久化 —— 这些由上层编排。
 *
 * 对应上游 lx-music-mobile 的 `src/store/player` 中的播放列表部分。
 */
import { MusicInfo } from '../../model/MusicInfo'

/** 移除一首歌后的结果（供上层决定是否接着播放下一曲） */
export interface QueueRemoveResult {
  /** 是否真的移除了 */
  removed: boolean
  /** 被移除的是否正是当前播放的那首 */
  removedCurrent: boolean
  /** 移除后的当前索引；队列已空时为 -1 */
  currentIndex: number
  /** removedCurrent 为 true 时，需要接着播放的索引（队列尾则回到 0） */
  nextIndex: number
}

/** 播放历史栈容量上限：超过后丢弃最旧的记录 */
const HISTORY_LIMIT: number = 50

export class PlayQueue {
  private items: MusicInfo[] = []
  private index: number = -1
  /** 播放历史（存歌曲本身而非索引，避免队列增删后历史失效） */
  private history: MusicInfo[] = []

  get size(): number {
    return this.items.length
  }

  getList(): MusicInfo[] {
    return this.items
  }

  getIndex(): number {
    return this.index
  }

  getCurrent(): MusicInfo | undefined {
    if (this.index >= 0 && this.index < this.items.length) {
      return this.items[this.index]
    }
    return undefined
  }

  /** 装载队列并定位当前曲目（不触发播放） */
  setList(musics: MusicInfo[], startIndex: number): void {
    this.items = musics.slice()
    if (this.items.length === 0) {
      this.index = -1
      return
    }
    this.index = Math.min(Math.max(startIndex, 0), this.items.length - 1)
  }

  setIndex(i: number): void {
    if (i < 0 || i >= this.items.length) {
      return
    }
    this.index = i
  }

  /**
   * 移除队列中第 index 首。
   * - 移除非当前曲：删除后修正当前索引；
   * - 移除当前曲：上层需按 nextIndex 接着播放（队列尾则回到 0）；队列清空则停止。
   */
  removeAt(index: number): QueueRemoveResult {
    const empty: QueueRemoveResult = {
      removed: false,
      removedCurrent: false,
      currentIndex: this.index,
      nextIndex: -1
    }
    if (index < 0 || index >= this.items.length) {
      return empty
    }
    const removedCurrent: boolean = index === this.index
    this.items.splice(index, 1)
    if (this.items.length === 0) {
      this.index = -1
      const result: QueueRemoveResult = {
        removed: true,
        removedCurrent: removedCurrent,
        currentIndex: -1,
        nextIndex: -1
      }
      return result
    }
    if (!removedCurrent) {
      // 移除位置在当前曲之前 → 当前索引整体前移一位
      if (index < this.index) {
        this.index--
      }
      const result: QueueRemoveResult = {
        removed: true,
        removedCurrent: false,
        currentIndex: this.index,
        nextIndex: -1
      }
      return result
    }
    // 移除的正是当前曲：同位置的原下一曲继续播（队列尾则从头）
    const next: number = index >= this.items.length ? 0 : index
    this.index = next
    const result: QueueRemoveResult = {
      removed: true,
      removedCurrent: true,
      currentIndex: next,
      nextIndex: next
    }
    return result
  }

  /** 队列内重排：把 from 位置的歌曲移到 to 位置 */
  move(from: number, to: number): boolean {
    if (from < 0 || from >= this.items.length || to < 0 || to >= this.items.length || from === to) {
      return false
    }
    const item: MusicInfo = this.items[from]
    this.items.splice(from, 1)
    this.items.splice(to, 0, item)
    // 当前曲跟着搬家，索引要跟着修正
    if (this.index === from) {
      this.index = to
    } else if (from < this.index && to >= this.index) {
      this.index--
    } else if (from > this.index && to <= this.index) {
      this.index++
    }
    return true
  }

  /** 在指定位置插入一首歌 */
  insertAt(index: number, music: MusicInfo): boolean {
    if (index < 0 || index > this.items.length) {
      return false
    }
    this.items.splice(index, 0, music)
    if (this.index >= index) {
      this.index++
    }
    return true
  }

  /** 替换队列中第 index 首（换源播放用） */
  replaceAt(index: number, music: MusicInfo): boolean {
    if (index < 0 || index >= this.items.length) {
      return false
    }
    this.items[index] = music
    return true
  }

  /** 清空队列 */
  clear(): void {
    this.items = []
    this.index = -1
  }

  // ---- 播放历史（随机模式下「上一首」的来源） ----

  /** 记下一首刚播过的歌（切歌时调用） */
  pushHistory(music: MusicInfo | undefined): void {
    if (music == undefined) {
      return
    }
    this.history.push(music)
    while (this.history.length > HISTORY_LIMIT) {
      this.history.shift()
    }
  }

  /** 取出并移除最近一条历史 */
  popHistory(): MusicInfo | undefined {
    if (this.history.length === 0) {
      return undefined
    }
    const last: MusicInfo = this.history[this.history.length - 1]
    this.history.pop()
    return last
  }

  /** 查看最近一条历史但不取出 */
  peekHistory(): MusicInfo | undefined {
    if (this.history.length === 0) {
      return undefined
    }
    return this.history[this.history.length - 1]
  }

  /** 历史歌曲在当前队列中的索引；不在队列里（已被移除）返回 -1 */
  historyIndexInQueue(): number {
    const last: MusicInfo | undefined = this.peekHistory()
    if (last == undefined) {
      return -1
    }
    return this.indexOfId(last.id)
  }

  /** 按歌曲 id 在当前队列中查找索引；找不到返回 -1 */
  indexOfId(musicId: string): number {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].id === musicId) {
        return i
      }
    }
    return -1
  }

  /** 清空播放历史 */
  clearHistory(): void {
    this.history = []
  }
}
