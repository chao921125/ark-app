/**
 * 播放模式策略 — 播放域的纯函数模块（无状态、无 IO、无平台 API）
 *
 * 只回答一个问题：给定当前模式与队列状态，上一首/下一首应该落在哪个索引。
 * 抽成纯函数是为了让边界规则可以被确定性验证（见 docs/refactor-plan-v2.md §3.3）。
 */
import { PlayMode } from '../../model/AppSettings'

/** 随机取值时的最大重试次数：超过则用确定性兜底，避免死循环 */
export const RANDOM_RETRY_LIMIT: number = 32

/**
 * 下一首的索引。
 *
 * - listLoop / singleLoop：顺序下一曲，末尾回到 0。
 * - listRandom：随机取一首**不同于当前**的歌。
 *
 * 注意：singleLoop 只影响「播完自动续播」，手动点下一首照常切下一曲
 * （与上游 lx-music 的行为一致）。
 */
export function nextIndex(mode: PlayMode, curIndex: number, size: number): number {
  if (size <= 0) {
    return -1
  }
  if (size === 1) {
    return 0
  }
  if (mode === 'listRandom') {
    let idx: number = curIndex
    for (let i = 0; i < RANDOM_RETRY_LIMIT && idx === curIndex; i++) {
      idx = Math.floor(Math.random() * size)
    }
    if (idx === curIndex) {
      // 极端情况（size 极小且随机数连续同值）下的确定性兜底
      idx = (curIndex + 1) % size
    }
    return idx
  }
  return (curIndex + 1) % size
}

/**
 * 上一首的索引。
 *
 * - listLoop / singleLoop：顺序上一曲，开头回到末尾。
 * - listRandom：随机取一首（**不同于当前**的歌）。
 *
 * 注意：随机模式下「上一首」应优先回到播放历史，那属于**有状态**的队列逻辑，
 * 由 core/queue/PlayQueue 负责；本函数只负责无历史可依时的随机兜底。
 */
export function prevIndex(mode: PlayMode, curIndex: number, size: number): number {
  if (size <= 0) {
    return -1
  }
  if (size === 1) {
    return 0
  }
  if (mode == 'listRandom') {
    let idx: number = curIndex
    for (let i = 0; i < RANDOM_RETRY_LIMIT && idx === curIndex; i++) {
      idx = Math.floor(Math.random() * size)
    }
    if (idx === curIndex) {
      idx = (curIndex - 1 + size) % size
    }
    return idx
  }
  return (curIndex - 1 + size) % size
}
