/**
 * 聚合搜索的歌曲匹配与去重 — 纯逻辑模块（无平台依赖，可被验证台直接覆盖）
 *
 * 对齐上游 lx-music-desktop `findMusic` 的思路：
 *  - 歌名/歌手统一清洗（去括号后缀、去空格与标点、转小写）后再比较；
 *  - 同一首歌在多个音源的结果合并为一条，**保留音质更高的那条**（flac24bit > flac > 320k > 128k）。
 */

/** 归一化时剔除的标点与空白 */
const PUNCTUATION_EXP = /[\s\-_.、,，。~～!！?？:：;；'"“”‘’()（）\[\]【】<>《》|/\\*&#@~`^+=]/g

/** 括号及其内容（如「(DJ版)」「[Live]」「【高音质】」） */
const BRACKET_CONTENT_EXP = /[（(【\[].*?[）)】\]]/g

/**
 * 歌名归一化：去掉括号后缀、标点与空白，转小写。
 * 「花海 (DJ 阿若版)」→「花海」
 */
export function normalizeSongName(name: string): string {
  return name
    .replace(BRACKET_CONTENT_EXP, '')
    .replace(PUNCTUATION_EXP, '')
    .toLowerCase()
    .trim()
}

/**
 * 歌手归一化：多人歌手按分隔符拆开排序后拼接，
 * 使「周杰伦/五月天」与「五月天,周杰伦」视为同一人组合。
 */
export function normalizeSinger(singer: string): string {
  const parts: string[] = singer
    .split(/[\/、,&，\s]+/)
    .map(part => part.replace(PUNCTUATION_EXP, '').toLowerCase())
    .filter(part => part.length > 0)
  parts.sort()
  return parts.join('')
}

/** 同一首歌的判定键：归一化后的「歌名 + 歌手」 */
export function songMatchKey(name: string, singer: string): string {
  return `${normalizeSongName(name)}|${normalizeSinger(singer)}`
}

/**
 * 音质由高到低的顺序（与 AppSettings.QUALITY_LADDER 保持一致，额外覆盖 ape）。
 * 下标越小音质越高。
 */
const QUALITY_ORDER: string[] = ['flac24bit', 'flac', 'ape', '320k', '128k']

/** 取可用音质中的最高档；没有可用音质时返回空串 */
export function topQuality(qualitys: string[]): string {
  let best: string = ''
  let bestRank: number = QUALITY_ORDER.length
  for (let i = 0; i < qualitys.length; i++) {
    const rank: number = QUALITY_ORDER.indexOf(qualitys[i])
    if (rank >= 0 && rank < bestRank) {
      bestRank = rank
      best = qualitys[i]
    }
  }
  return best
}

/**
 * 音质徽标文案。
 *
 * lx-music-mobile 只标高于 128k 的档位，lx-music-desktop 则全部显示。
 * 这里取后者的口径（**每首歌都能看到音质**），高档位用醒目色区分：
 * 无损24 / 无损 / 高品 / 128k。
 * @returns 徽标文案；无音质信息时返回空串
 */
export function qualityBadgeText(quality: string): string {
  if (quality == 'flac24bit') {
    return '无损24'
  }
  if (quality == 'flac' || quality == 'ape') {
    return '无损'
  }
  if (quality == '320k') {
    return '高品'
  }
  if (quality == '128k') {
    return '128k'
  }
  return ''
}

/** 音质档位（用于徽标配色） */
export type QualityLevel = 'lossless24' | 'lossless' | 'high' | 'standard' | 'none'

/** 音质档位判定：决定徽标用哪种颜色 */
export function qualityLevel(quality: string): QualityLevel {
  if (quality == 'flac24bit') {
    return 'lossless24'
  }
  if (quality == 'flac' || quality == 'ape') {
    return 'lossless'
  }
  if (quality == '320k') {
    return 'high'
  }
  if (quality == '128k') {
    return 'standard'
  }
  return 'none'
}

/** 取一条歌曲可用音质中的最高档；取不到时按 128k 处理 */
export function bestQualityIndex(qualitys: string[]): number {
  let best: number = QUALITY_ORDER.length - 1
  for (let i = 0; i < qualitys.length; i++) {
    const idx: number = QUALITY_ORDER.indexOf(qualitys[i])
    if (idx >= 0 && idx < best) {
      best = idx
    }
  }
  return best
}

/** 带音质列表的歌曲（用于比较两条结果谁音质更高） */
export interface QualityHolder {
  qualitys: string[]
}

/**
 * 合并同一首歌时该保留哪一条：音质更高的优先；
 * 音质相同时保留先到的那条（保持音源优先级顺序，结果顺序稳定）。
 */
export function pickBetter(existing: QualityHolder, incoming: QualityHolder): boolean {
  return bestQualityIndex(incoming.qualitys) < bestQualityIndex(existing.qualitys)
}
