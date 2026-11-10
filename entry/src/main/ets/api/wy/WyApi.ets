/**
 * 网易云(wy)在线音源 API — 对齐上游 lx-music-mobile `src/utils/musicSdk/wy/`
 *  - musicSearch.js: POST eapi('/api/cloudsearch/pc') → { result: { songs: [...] } }
 *    （上游启用的 /api/search/song/list/page 与 cloudsearch 歌曲字段同构，取标准 cloudsearch）
 *  - musicUrl:       POST eapi('/api/song/enhance/player/url') → { data: [{ url }] }
 *    （上游 v1.8.4 播放链接走自定义源；此处内置 NeteaseCloudMusicApi 标准直链接口，
 *      未登录可取免费曲目直链，VIP/无版权曲目 url=null 走失败路径）
 *  - lyric.js:       POST eapi('/api/song/lyric/v1') → { lrc, tlyric, romalrc, yrc }
 *    含上游 fixTimeLabel（[mm:ss:xx]→[mm:ss.xx]）与 yrc JSON 行简化解析。
 * 响应做防御式解析：字段缺失/结构变化 → 空数组/空串（不抛错）；
 * 网络层错误由 HttpUtil 抛归一 BusinessError，交由调用方 catch 提示。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { MusicInfo, MusicInfoMetaOnline, QualityInfo, LyricInfo, isLocalInfo } from '../../model/MusicInfo'
import { formatTime } from '../../utils/FormatUtil'
import { httpPostForm, ERR_HTTP_REQUEST_FAILED, NormalizedError } from '../../utils/HttpUtil'
import { WyCrypto } from './WyCrypto'

const TAG = 'WyApi'
const DOMAIN = 0x0001

const SEARCH_API_PATH = '/api/cloudsearch/pc'
const SEARCH_URL = 'https://interface3.music.163.com/eapi/cloudsearch/pc'
const MUSIC_URL_API_PATH = '/api/song/enhance/player/url'
const MUSIC_URL_URL = 'https://interface3.music.163.com/eapi/song/enhance/player/url'
const LYRIC_API_PATH = '/api/song/lyric/v1'
const LYRIC_URL = 'https://interface3.music.163.com/eapi/song/lyric/v1'

/** 上游 wy 各请求的固定 UA / origin */
const HEADERS: Record<string, string> = {
  'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36',
  'origin': 'https://music.163.com'
}

/** 搜索每页数量（对齐上游 musicSearch.limit） */
const SEARCH_LIMIT = 30
const SUGGEST_API_PATH = '/api/search/suggest/web'
const SUGGEST_URL = 'https://interface3.music.163.com/eapi/search/suggest/web'

function makeBizError(message: string): NormalizedError {
  return new NormalizedError(ERR_HTTP_REQUEST_FAILED, message)
}

function safeStr(v: string | undefined | null): string {
  return v == undefined || v == null ? '' : v
}

/** 对齐上游 sizeFormate：B→K→M */
function sizeFormate(size: number | undefined): string | null {
  if (size == undefined || size <= 0) {
    return null
  }
  if (size > 1024 * 1024) {
    return `${(size / 1024 / 1024).toFixed(2)}M`
  }
  if (size > 1024) {
    return `${(size / 1024).toFixed(2)}K`
  }
  return `${size}B`
}

/** 质量 → eapi br 参数（对齐 NeteaseCloudMusicApi song_url 映射） */
function brOf(quality: string): number {
  if (quality == '320k') {
    return 320000
  }
  if (quality == 'flac' || quality == 'flac24bit') {
    return 999000
  }
  return 128000
}

/* ---------------- 响应形状（防御式：全部字段可选） ---------------- */

interface WyArtist {
  name?: string
}

interface WyAlbum {
  name?: string
  picUrl?: string
}

interface WyQualityNode {
  size?: number
}

interface WySongPrivilege {
  maxbr?: number
  maxBrLevel?: string
}

interface WySong {
  id?: number
  name?: string
  ar?: WyArtist[]
  al?: WyAlbum
  dt?: number
  privilege?: WySongPrivilege
  h?: WyQualityNode
  l?: WyQualityNode
  sq?: WyQualityNode
  hr?: WyQualityNode
}

interface WySearchResult {
  songs?: WySong[]
  songCount?: number
}

interface WySearchResp {
  code?: number
  result?: WySearchResult
}

interface WyUrlData {
  id?: number
  url?: string | null
}

interface WyUrlResp {
  code?: number
  data?: WyUrlData[]
}

interface WyLyricPart {
  lyric?: string
}

interface WyLyricResp {
  code?: number
  lrc?: WyLyricPart
  tlyric?: WyLyricPart
  romalrc?: WyLyricPart
  yrc?: WyLyricPart
}

interface WyYrcToken {
  tx?: string
}

interface WyYrcInfo {
  t?: number
  c?: WyYrcToken[]
}

/* ---------------- eapi 请求负载（显式类型，ArkTS 禁止裸字面量） ---------------- */

interface WySearchPayload {
  s: string
  type: number
  limit: number
  total: boolean
  offset: number
}

interface WyUrlPayload {
  ids: string
  br: number
  csrf_token: string
}

interface WyLyricPayload {
  id: string
  cp: boolean
  tv: number
  lv: number
  rv: number
  kv: number
  yv: number
  ytv: number
  yrv: number
}

/* ---------------- 歌词处理（对齐上游 lyric.js） ---------------- */

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`
}

/** ms → [mm:ss.xx] LRC 时间标签 */
function msToTag(ms: number): string {
  const total = Math.max(0, Math.floor(ms))
  const mm = Math.floor(total / 60000)
  const ss = Math.floor((total % 60000) / 1000)
  const xx = Math.floor((total % 1000) / 10)
  return `${pad2(mm)}:${pad2(ss)}.${pad2(xx)}`
}

/** 上游 fixTimeLabel：wy 老格式 [mm:ss:xx] → 标准 [mm:ss.xx] */
function fixTimeLabel(lrc: string | undefined): string {
  if (lrc == undefined || lrc.length == 0) {
    return ''
  }
  return lrc.replace(/\[(\d{2}:\d{2}):(\d{2})]/g, '[$1.$2]')
}

/** yrc（逐字歌词 JSON 行）→ 标准 LRC 行（简化版 parseHeaderInfo：逐行还原为 [时间]文本） */
function parseYrc(yrc: string): string {
  const lines = yrc.replace(/\r/g, '').split('\n')
  const out: string[] = []
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim()
    if (line.length == 0) {
      continue
    }
    if (line.startsWith('{')) {
      try {
        const info = JSON.parse(line) as WyYrcInfo
        if (typeof info.t == 'number' && !Number.isNaN(info.t) && info.c != undefined) {
          const text = info.c.map((tok: WyYrcToken) => safeStr(tok.tx)).join('')
          if (text.trim().length > 0) {
            out.push(`[${msToTag(info.t)}]${text}`)
          }
        }
      } catch (ignored) {
        // 非 JSON 行忽略
      }
    } else if (line.startsWith('[')) {
      out.push(line)
    }
  }
  return out.join('\n')
}

/** 从 MusicInfo 提取 wy songId */
function getSongId(music: MusicInfo): string {
  if (isLocalInfo(music.meta)) {
    return ''
  }
  const meta = music.meta as MusicInfoMetaOnline
  return meta.songId
}

interface WySuggestArtist {
  name?: string
}

interface WySuggestSong {
  name?: string
  artists?: WySuggestArtist[]
}

interface WySuggestResult {
  songs?: WySuggestSong[]
}

interface WySuggestResp {
  result?: WySuggestResult
}


export class WyApi {
  /** 关键词搜索 → MusicInfo[]（source='wy'，id='wy_'+songId） */
  static async search(keyword: string): Promise<MusicInfo[]> {
    const kw = keyword.trim()
    if (kw.length == 0) {
      return []
    }
    const payload: WySearchPayload = {
      s: kw,
      type: 1,
      limit: SEARCH_LIMIT,
      total: true,
      offset: 0
    }
    const form: Record<string, string> = await WyCrypto.eapi(SEARCH_API_PATH, payload)
    const resp = await httpPostForm(SEARCH_URL, form, HEADERS)
    let parsed: WySearchResp
    try {
      parsed = JSON.parse(resp.body) as WySearchResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'search parse failed: %{public}s', resp.body.substring(0, 200))
      return []
    }
    if (parsed.code != 200) {
      hilog.error(DOMAIN, TAG, 'search bad code: %{public}d', parsed.code ?? 0)
      throw makeBizError(`wy search code ${parsed.code ?? 'unknown'}`)
    }
    const songs = parsed.result != undefined ? parsed.result.songs : undefined
    if (songs == undefined || songs.length == 0) {
      return []
    }
    const result: MusicInfo[] = []
    for (let i = 0; i < songs.length; i++) {
      const song = songs[i]
      const songId = song.id
      const name = safeStr(song.name).trim()
      if (typeof songId != 'number' || name.length == 0) {
        continue
      }
      // 质量：128k 恒有；按 h/sq/hr 依次补 320k/flac/flac24bit（对齐上游 handleResult）
      const qualitys: QualityInfo[] = [{ type: '128k', size: sizeFormate(song.l?.size) }]
      if (song.h != undefined) {
        const q320: QualityInfo = { type: '320k', size: sizeFormate(song.h.size) }
        qualitys.push(q320)
      }
      if (song.sq != undefined) {
        const qFlac: QualityInfo = { type: 'flac', size: sizeFormate(song.sq.size) }
        qualitys.push(qFlac)
      }
      if (song.hr != undefined) {
        const qHr: QualityInfo = { type: 'flac24bit', size: sizeFormate(song.hr.size) }
        qualitys.push(qHr)
      }
      const singers: string[] = []
      const ars = song.ar
      if (ars != undefined) {
        for (let j = 0; j < ars.length; j++) {
          const singerName = safeStr(ars[j].name).trim()
          if (singerName.length > 0) {
            singers.push(singerName)
          }
        }
      }
      const meta: MusicInfoMetaOnline = {
        songId: `${songId}`,
        albumName: safeStr(song.al?.name).trim(),
        picUrl: song.al?.picUrl != undefined ? song.al.picUrl : null,
        qualitys: qualitys
      }
      const music: MusicInfo = {
        id: `wy_${songId}`,
        name: name,
        singer: singers.join('、'),
        source: 'wy',
        interval: typeof song.dt == 'number' && song.dt > 0 ? formatTime(song.dt / 1000) : null,
        meta: meta
      }
      result.push(music)
    }
    return result
  }

  /** music + quality → 可播放直链；取不到（VIP/无版权）返回空串（调用方走失败路径） */
  static async getMusicUrl(music: MusicInfo, quality: string): Promise<string> {
    const songId = getSongId(music)
    if (songId.length == 0) {
      throw makeBizError('wy: music has no songId')
    }
    const id = songId.trim()
    const payload: WyUrlPayload = {
      ids: `[${id}]`,
      br: brOf(quality),
      csrf_token: ''
    }
    const form: Record<string, string> = await WyCrypto.eapi(MUSIC_URL_API_PATH, payload)
    const resp = await httpPostForm(MUSIC_URL_URL, form, HEADERS)
    let parsed: WyUrlResp
    try {
      parsed = JSON.parse(resp.body) as WyUrlResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'musicUrl parse failed: rid=%{public}s', id)
      return ''
    }
    if (parsed.code != 200) {
      hilog.error(DOMAIN, TAG, 'musicUrl bad code: %{public}d rid=%{public}s', parsed.code ?? 0, id)
      throw makeBizError(`wy musicUrl code ${parsed.code ?? 'unknown'}`)
    }
    const data = parsed.data
    if (data == undefined || data.length == 0) {
      return ''
    }
    const url = data[0].url
    if (url == undefined || url == null || url.trim().length == 0) {
      hilog.error(DOMAIN, TAG, 'musicUrl empty (vip/copyright?): rid=%{public}s', id)
      return ''
    }
    return url.trim()
  }

  /** music → 歌词（lrc/tlyric/romalrc；yrc 简化还原）；无歌词返回 { lyric: '' } */
  static async getLyric(music: MusicInfo): Promise<LyricInfo> {
    const songId = getSongId(music)
    if (songId.length == 0) {
      return { lyric: '' }
    }
    const id = songId.trim()
    const payload: WyLyricPayload = {
      id: id,
      cp: false,
      tv: 0,
      lv: 0,
      rv: 0,
      kv: 0,
      yv: 0,
      ytv: 0,
      yrv: 0
    }
    const form: Record<string, string> = await WyCrypto.eapi(LYRIC_API_PATH, payload)
    const resp = await httpPostForm(LYRIC_URL, form, HEADERS)
    let parsed: WyLyricResp
    try {
      parsed = JSON.parse(resp.body) as WyLyricResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'lyric parse failed: rid=%{public}s', id)
      return { lyric: '' }
    }
    if (parsed.code != 200) {
      hilog.error(DOMAIN, TAG, 'lyric bad code: %{public}d rid=%{public}s', parsed.code ?? 0, id)
      return { lyric: '' }
    }
    let lyric = fixTimeLabel(parsed.lrc != undefined ? parsed.lrc.lyric : undefined)
    if (lyric.trim().length == 0) {
      // 无标准 LRC 时用 yrc（逐字歌词）简化还原
      const yrc = parsed.yrc != undefined ? parsed.yrc.lyric : undefined
      if (yrc != undefined && yrc.length > 0) {
        lyric = parseYrc(yrc)
      }
    }
    if (lyric.trim().length == 0) {
      return { lyric: '' }
    }
    const info: LyricInfo = {
      lyric: lyric,
      tlyric: fixTimeLabel(parsed.tlyric != undefined ? parsed.tlyric.lyric : undefined),
      rlyric: fixTimeLabel(parsed.romalrc != undefined ? parsed.romalrc.lyric : undefined)
    }
    return info
  }

  /**
   * 搜索联想（对齐 lx-music-desktop wy/tipSearch.js）：
   * POST /eapi/search/suggest/web → result.songs[] → 「歌名 - 歌手」
   * 沿用本项目 wy 现有的 eapi 通道（比 weapi 少一次 RSA 加密，联想这种高频请求更合适）。
   */
  static async suggest(keyword: string): Promise<string[]> {
    const kw = keyword.trim()
    if (kw.length === 0) {
      return []
    }
    const payload: Record<string, string> = { 's': kw }
    const form: Record<string, string> = await WyCrypto.eapi(SUGGEST_API_PATH, payload)
    const resp = await httpPostForm(SUGGEST_URL, form, HEADERS)
    let parsed: WySuggestResp
    try {
      parsed = JSON.parse(resp.body) as WySuggestResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'suggest parse failed: %{public}s', resp.body.substring(0, 200))
      return []
    }
    const songs: WySuggestSong[] = parsed.result?.songs ?? []
    const out: string[] = []
    for (let i = 0; i < songs.length; i++) {
      const name = songs[i].name ?? ''
      if (name.length === 0) {
        continue
      }
      const artists: WySuggestArtist[] = songs[i].artists ?? []
      const names: string[] = []
      for (let j = 0; j < artists.length; j++) {
        const an = artists[j].name ?? ''
        if (an.length > 0) {
          names.push(an)
        }
      }
      out.push(names.length > 0 ? `${name} - ${names.join('/')}` : name)
    }
    return out
  }

}