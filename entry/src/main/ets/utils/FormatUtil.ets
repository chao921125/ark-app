/**
 * 通用工具 — 对齐上游 `src/utils/common.ts` 的时间格式化与本地文件名解析
 */

export function formatTime(sec: number): string {
  if (!Number.isFinite(sec) || sec < 0) {
    return '00:00'
  }
  const total = Math.floor(sec)
  const mm = Math.floor(total / 60)
  const ss = total % 60
  const mmStr = mm < 10 ? `0${mm}` : `${mm}`
  const ssStr = ss < 10 ? `0${ss}` : `${ss}`
  return `${mmStr}:${ssStr}`
}

export interface ParsedName {
  name: string
  singer: string
}

/**
 * 文件名解析 — 对齐上游 `src/core/music/utils.ts` 的 "歌手 - 歌名" 约定：
 * 优先按 " - " 分割，分割不出则歌手留空。
 */
export function parseNameFromFileName(fileName: string): ParsedName {
  const dotIdx = fileName.lastIndexOf('.')
  let base = dotIdx > 0 ? fileName.substring(0, dotIdx) : fileName
  base = base.trim()
  const sepIdx = base.indexOf(' - ')
  if (sepIdx > 0) {
    const singer = base.substring(0, sepIdx).trim()
    const name = base.substring(sepIdx + 3).trim()
    if (singer.length > 0 && name.length > 0) {
      return { name: name, singer: singer }
    }
  }
  return { name: base, singer: '' }
}

export function getExt(fileName: string): string {
  const dotIdx = fileName.lastIndexOf('.')
  if (dotIdx < 0 || dotIdx == fileName.length - 1) {
    return ''
  }
  return fileName.substring(dotIdx + 1).toLowerCase()
}

/** djb2 字符串哈希，用于从文件路径生成稳定 id */
export function hashString(input: string): string {
  let h = 5381
  for (let i = 0; i < input.length; i++) {
    h = ((h << 5) + h + input.charCodeAt(i)) | 0
  }
  const unsigned = h >>> 0
  return `${unsigned}`
}

export const SUPPORTED_AUDIO_EXTS: string[] = ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'ape', 'wma']