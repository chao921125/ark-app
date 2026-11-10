/**
 * 音量刻度换算 — 应用内音量（0–100）与播放器相对音量（0.00–1.00）之间的转换
 *
 * 【为什么单独成文件】
 * 这是纯粹的刻度换算规则，却曾因「把 0–100 直接传给只接受 0.00–1.00 的接口」而引发
 * 线上报错：AVPlayer.setVolume 的合法范围是 0.00–1.00，越界会触发
 * errorCode 401「Invalid Parameter: invalid parameters, check volume level」。
 * 该错误经 player.on('error') 上报，表现为「播放时弹出一个英文报错，但歌照常在放」。
 *
 * 抽成无依赖的纯函数，既能钉死这条契约（可单测），也避免换算逻辑散落在调用处。
 */

/** 最小音量（0–100 刻度） */
export const MIN_VOLUME: number = 0
/** 最大音量（0–100 刻度） */
export const MAX_VOLUME: number = 100
/** 默认音量（0–100 刻度） */
export const DEFAULT_VOLUME: number = 100

/**
 * 应用内音量（0–100）→ AVPlayer 相对音量（0.00–1.00）。
 * 1.00 表示最大音量。越界值一律夹到 [0,1]，避免触发接口的参数校验错误。
 */
export function toPlayerVolume(userVolume: number): number {
  if (isNaN(userVolume)) {
    return 1
  }
  const ratio: number = userVolume / MAX_VOLUME
  return Math.min(Math.max(ratio, MIN_VOLUME), 1)
}
