/**
 * LRC 歌词解析器
 * 移植自上游 lx-music-mobile：
 *  - `src/utils/lrcTools.ts`（时间标签正则与多标签处理）
 *  - 依赖库 `lrc-file-parser` 的行为（按时间排序、二分定位当前行）
 */

const TIME_FIELD_EXP = /^(?:\[[\d:.]+\])+/
const TIME_EXP = /\d{1,3}(:\d{1,3}){0,2}(?:\.\d{1,3})/g

/**
 * 识别「占位歌词」：部分音源查不到歌词时会返回一段占位文本
 * （如「暂无歌词」+ 作词/作曲等元信息，甚至只有元信息没有歌词行）。
 * 这类内容必须判为「未找到」并继续换下一个音源 / 不展示给用户，
 * 否则用户会看到一屏元信息却以为已找到歌词。
 */
export function isPlaceholderLyric(text: string): boolean {
  const t: string = text.trim()
  if (t.length === 0) {
    return true
  }
  const rest: string = t
    .split('\n')
    .filter(line => !/作词|作曲|编曲|混音|录音|音频剪辑|策划|统筹|出品|发行|监制|和声|母带|封面|制作人|OP\s*:/i.test(line))
    .filter(line => !/^[\[【（(].*[\]】）)]$/.test(line.trim()))
    .join('')
    .trim()
  if (rest.length === 0) {
    return true
  }
  return rest.indexOf('暂无歌词') >= 0 || rest.indexOf('无歌词') >= 0 || rest.indexOf('没有歌词') >= 0
}

export interface LyricLine {
  /** 毫秒 */
  time: number
  text: string
}

interface TimeParsed {
  time: number
  /** 还原为规范化标签字符串，用于翻译歌词按标签合并 */
  label: string
}

function parseOneTime(raw: string): TimeParsed {
  // 形如 "12:34.56" / "34.56" / "01:02:03.456"
  const dotIndex = raw.lastIndexOf('.')
  let mainPart = raw
  let fracStr = '0'
  if (dotIndex >= 0) {
    mainPart = raw.substring(0, dotIndex)
    fracStr = raw.substring(dotIndex + 1)
  }
  const segs = mainPart.split(':')
  let ms = 0
  for (let i = 0; i < segs.length; i++) {
    ms = ms * 60 + parseInt(segs[i], 10)
  }
  ms = ms * 1000
  // 小数部分按毫秒补齐
  let frac = parseInt(fracStr, 10)
  if (fracStr.length == 1) {
    frac = frac * 100
  } else if (fracStr.length == 2) {
    frac = frac * 10
  }
  ms += frac
  return { time: ms, label: raw }
}

export class LyricParser {
  /**
   * 解析 LRC 文本为按时间排序的行数组。
   * 支持一行多时间标签 `[00:10.00][01:20.00]歌词`；忽略空行与元数据标签。
   */
  static parse(lrc: string): LyricLine[] {
    const lines: LyricLine[] = []
    if (lrc == undefined || lrc.length == 0) {
      return lines
    }
    const rawLines = lrc.split(/\r\n|\n|\r/)
    for (let i = 0; i < rawLines.length; i++) {
      const line = rawLines[i].trim()
      if (line.length == 0) {
        continue
      }
      const match = line.match(TIME_FIELD_EXP)
      if (match == null) {
        continue
      }
      const timeField = match[0]
      const text = line.replace(TIME_FIELD_EXP, '').trim()
      if (text.length == 0) {
        continue
      }
      const times = timeField.match(TIME_EXP)
      if (times == null) {
        continue
      }
      for (let t = 0; t < times.length; t++) {
        const parsed = parseOneTime(times[t])
        lines.push({ time: parsed.time, text: text })
      }
    }
    lines.sort((a, b) => a.time - b.time)
    return lines
  }

  /**
   * 定位当前应显示的行索引（最后一个 time <= progressMs 的行）。
   * 若进度早于首行返回 0。
   */
  static findLineIndex(lines: LyricLine[], progressMs: number): number {
    if (lines.length == 0) {
      return -1
    }
    let low = 0
    let high = lines.length - 1
    let ans = 0
    while (low <= high) {
      const mid = (low + high) >> 1
      if (lines[mid].time <= progressMs) {
        ans = mid
        low = mid + 1
      } else {
        high = mid - 1
      }
    }
    return ans
  }

  /**
   * 合并翻译歌词：按时间标签匹配，把翻译追加到对应行文本后。
   */
  static mergeTranslation(lines: LyricLine[], tlyric: string): LyricLine[] {
    if (tlyric == undefined || tlyric.trim().length == 0) {
      return lines
    }
    const tMap = new Map<string, string>()
    const rawLines = tlyric.split(/\r\n|\n|\r/)
    for (let i = 0; i < rawLines.length; i++) {
      const line = rawLines[i].trim()
      if (line.length == 0) {
        continue
      }
      const match = line.match(TIME_FIELD_EXP)
      if (match == null) {
        continue
      }
      const text = line.replace(TIME_FIELD_EXP, '').trim()
      if (text.length == 0) {
        continue
      }
      const times = match[0].match(TIME_EXP)
      if (times == null) {
        continue
      }
      for (let t = 0; t < times.length; t++) {
        tMap.set(times[t], text)
      }
    }
    if (tMap.size == 0) {
      return lines
    }
    const merged: LyricLine[] = []
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const label = LyricParser.msToLabel(line.time)
      const tText = tMap.get(label)
      if (tText != undefined) {
        merged.push({ time: line.time, text: `${line.text}\n${tText}` })
      } else {
        merged.push(line)
      }
    }
    return merged
  }

  /** 毫秒 → "mm:ss.xx" 标签（供翻译合并匹配） */
  static msToLabel(ms: number): string {
    const totalSec = Math.floor(ms / 1000)
    const mm = Math.floor(totalSec / 60)
    const ss = totalSec % 60
    const xx = Math.floor((ms % 1000) / 10)
    const mmStr = mm < 10 ? `0${mm}` : `${mm}`
    const ssStr = ss < 10 ? `0${ss}` : `${ss}`
    const xxStr = xx < 10 ? `0${xx}` : `${xx}`
    return `${mmStr}:${ssStr}.${xxStr}`
  }
}