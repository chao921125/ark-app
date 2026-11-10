/**
 * 酷我(kw)在线音源 API — 对齐上游 lx-music-mobile `src/utils/musicSdk/kw/`
 *  - musicSearch.js: https://search.kuwo.cn/r.s (pcjson=1) → { abslist: [...] }（新版；旧版为 { datas: [...] }，双兼容）
 *    新版字段：SONGNAME/ARTIST/ALBUM/DURATION(秒字符串)/MUSICRID("MUSIC_xxx")
 *  - musicUrl.js:    http://mobi.kuwo.cn/mobi.s?f=kuwo&q=<DES-ECB 加密参数串> → 文本 "u=<直链>&br=..."
 *  - lyric.js:       http://m.kuwo.cn/newh5/singles/songinfoandlrc?musicId= → { data: { lrclist: [...] } }
 * 响应做防御式解析：字段缺失/结构变化 → 返回空数组/空串（不抛错）；
 * 网络层错误（超时/非 200）由 HttpUtil 抛归一 BusinessError，交由调用方 catch 提示。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MusicInfo, MusicInfoMetaOnline, QualityInfo, LyricInfo, isLocalInfo } from '../../model/MusicInfo'
import { formatTime } from '../../utils/FormatUtil'
import { httpGetText, HttpResult, ERR_HTTP_REQUEST_FAILED, NormalizedError } from '../../utils/HttpUtil'
import { BusinessError } from '@kit.BasicServicesKit'
import { KwCrypto } from './KwCrypto'

const TAG = 'KwApi'
const DOMAIN = 0x0001

const SEARCH_URL = 'https://search.kuwo.cn/r.s'
const MUSIC_URL_API = 'https://mobi.kuwo.cn/mobi.s'
const LYRIC_URL = 'https://m.kuwo.cn/newh5/singles/songinfoandlrc'

/** 搜索每页数量 */
const SEARCH_LIMIT = 30

/** 质量 → (format, br)，对齐上游 musicUrl.js 的 qualityMap */
interface KwQuality {
  format: string
  br: string
}

const QUALITY_MAP: Map<string, KwQuality> = new Map()
QUALITY_MAP.set('128k', { format: 'mp3', br: '128kmp3' })
QUALITY_MAP.set('320k', { format: 'mp3', br: '320kmp3' })
QUALITY_MAP.set('flac', { format: 'flac', br: '2000kflac' })

/* ---------------- 响应形状（防御式：全部字段可选） ---------------- */

interface KwSearchItem {
  MUSICRID?: string
  SONGNAME?: string
  ARTIST?: string
  /** 旧版字段为 _ALBUM，新版 abslist 为 ALBUM */
  _ALBUM?: string
  ALBUM?: string
  DURATION?: string
}

interface KwSearchResp {
  /** 旧版结构 */
  datas?: KwSearchItem[]
  /** 新版结构（2025+ 返回 abslist，无 datas） */
  abslist?: KwSearchItem[]
}

interface KwLrcItem {
  time?: string
  lineLyric?: string
}

interface KwLrcData {
  lrclist?: KwLrcItem[]
}

interface KwLrcResp {
  data?: KwLrcData
}

/* ---------------- 解析辅助 ---------------- */

function safeStr(v: string | undefined): string {
  return v == undefined ? '' : v
}

/** 去掉标题中的 HTML 标记（kw 搜索结果常含 <em> 高亮标签） */
function stripHtml(s: string): string {
  return s.replace(/<[^>]*>/g, '')
}

/** MUSICRID 形如 "MUSIC_239651234" → "239651234" */
function songIdFromMusicrid(musicrid: string): string {
  let s = musicrid.trim()
  if (s.startsWith('MUSIC_')) {
    s = s.substring(6)
  }
  return s
}

/** 从 MusicInfo 提取 kw songId */
function getSongId(music: MusicInfo): string {
  if (isLocalInfo(music.meta)) {
    return ''
  }
  const meta = music.meta as MusicInfoMetaOnline
  return meta.songId
}

/** "10.36"（秒）→ "00:10.36" LRC 时间标签 */
function secToLrcTime(secStr: string): string {
  const sec = parseFloat(secStr)
  if (!Number.isFinite(sec) || sec < 0) {
    return '00:00.00'
  }
  const totalMs = Math.floor(sec * 1000)
  const mm = Math.floor(totalMs / 60000)
  const ss = Math.floor((totalMs % 60000) / 1000)
  const xx = Math.floor((totalMs % 1000) / 10)
  const mmStr = mm < 10 ? `0${mm}` : `${mm}`
  const ssStr = ss < 10 ? `0${ss}` : `${ss}`
  const xxStr = xx < 10 ? `0${xx}` : `${xx}`
  return `${mmStr}:${ssStr}.${xxStr}`
}

function makeBizError(message: string): NormalizedError {
  return new NormalizedError(ERR_HTTP_REQUEST_FAILED, message)
}

interface KwSuggestItem {
  RELWORD?: string
}

interface KwSuggestData {
  WORDITEMS?: KwSuggestItem[]
}

interface KwSuggestResp {
  /** 新版结构：data.WORDITEMS */
  data?: KwSuggestData
  /** 旧版结构：顶层 WORDITEMS */
  WORDITEMS?: KwSuggestItem[]
}


export class KwApi {
  /** 关键词搜索 → MusicInfo[]（source='kw'，id='kw_'+songId） */
  static async search(keyword: string): Promise<MusicInfo[]> {
    const kw = keyword.trim()
    if (kw.length == 0) {
      return []
    }
    const url = `${SEARCH_URL}?all=${encodeURIComponent(kw)}&ft=music&itemset=web_2018&client=kt&pn=0&rn=${SEARCH_LIMIT}&rformat=json&encoding=utf8&pcjson=1`
    const resp = await httpGetText(url)
    let parsed: KwSearchResp
    try {
      parsed = JSON.parse(resp.body) as KwSearchResp
    } catch (e) {
      // 结构变化 / 非 JSON → 防御式返回空数组
      hilog.error(DOMAIN, TAG, 'search parse failed: %{public}s', resp.body.substring(0, 200))
      return []
    }
    // 新版返回 abslist，旧版返回 datas，双兼容
    let datas = parsed.datas
    if (datas == undefined || datas.length == 0) {
      datas = parsed.abslist
    }
    if (datas == undefined || datas.length == 0) {
      return []
    }
    const result: MusicInfo[] = []
    for (let i = 0; i < datas.length; i++) {
      const item = datas[i]
      const songId = songIdFromMusicrid(safeStr(item.MUSICRID))
      const name = stripHtml(safeStr(item.SONGNAME)).trim()
      if (songId.length == 0 || name.length == 0) {
        continue
      }
      const durationSec = parseInt(safeStr(item.DURATION), 10)
      const qualitys: QualityInfo[] = [{ type: '128k', size: null }]
      const albumRaw = item.ALBUM != undefined ? item.ALBUM : item._ALBUM
      const meta: MusicInfoMetaOnline = {
        songId: songId,
        albumName: stripHtml(safeStr(albumRaw)).trim(),
        picUrl: null,
        qualitys: qualitys
      }
      const music: MusicInfo = {
        id: `kw_${songId}`,
        name: name,
        singer: stripHtml(safeStr(item.ARTIST)).trim(),
        source: 'kw',
        interval: Number.isNaN(durationSec) || durationSec <= 0 ? null : formatTime(durationSec),
        meta: meta
      }
      result.push(music)
    }
    return result
  }

  /** music + quality → 可播放直链（128k 等质量）；取不到返回空串（调用方走失败路径） */
  static async getMusicUrl(music: MusicInfo, quality: string): Promise<string> {
    const songId = getSongId(music)
    if (songId.length == 0) {
      throw makeBizError('kw: music has no songId')
    }
    const id = songId.trim()
    const q = QUALITY_MAP.get(quality) ?? QUALITY_MAP.get('128k') as KwQuality
    // 参数串与上游 musicUrl.js 一致：DES-ECB(ylzsxkwm) 加密后放 q=
    const plain = `corp=kuwo&p2p=1&type=convert_url2&sign=kw&format=${q.format}&br=${q.br}&rid=${id}`
    const enc = KwCrypto.encryptByDES(plain)
    const url = `${MUSIC_URL_API}?f=kuwo&q=${encodeURIComponent(enc)}`
    const resp = await httpGetText(url)
    // convert_url2 返回文本："u=<直链>&br=<码率>&..."（可能多行）
    const m = resp.body.match(/u=([^&\r\n]+)/)
    if (m == null || m[1] == undefined || m[1].trim().length == 0) {
      hilog.error(DOMAIN, TAG, 'musicUrl not found: rid=%{public}s body=%{public}s', id, resp.body.substring(0, 200))
      return ''
    }
    return m[1].trim()
  }

  /** music → 歌词（lrclist 拼成 LRC 文本）；无歌词返回 { lyric: '' } */
  static async getLyric(music: MusicInfo): Promise<LyricInfo> {
    const songId = getSongId(music)
    if (songId.length == 0) {
      return { lyric: '' }
    }
    const id = songId.trim()
    const url = `${LYRIC_URL}?musicId=${encodeURIComponent(id)}`
    const resp: HttpResult = await httpGetText(url)
    let parsed: KwLrcResp
    try {
      parsed = JSON.parse(resp.body) as KwLrcResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'lyric parse failed: rid=%{public}s', id)
      return { lyric: '' }
    }
    const data = parsed.data
    const lrcList = data != undefined ? data.lrclist : undefined
    if (lrcList == undefined || lrcList.length == 0) {
      return { lyric: '' }
    }
    const sb: string[] = []
    for (let i = 0; i < lrcList.length; i++) {
      const item = lrcList[i]
      const text = safeStr(item.lineLyric).trim()
      if (text.length == 0) {
        continue
      }
      sb.push(`[${secToLrcTime(safeStr(item.time))}]${text}`)
    }
    return { lyric: sb.join('\n') }
  }

  /**
   * 搜索联想（对齐 lx-music-desktop kw/tipSearch.js）：
   * GET https://tips.kuwo.cn/t.s?...&w=<关键词>&rformat=json → WORDITEMS[].RELWORD
   */
  static async suggest(keyword: string): Promise<string[]> {
    const kw = keyword.trim()
    if (kw.length === 0) {
      return []
    }
    const url = `https://tips.kuwo.cn/t.s?corp=kuwo&newver=3&p2p=1&notrace=0&c=mbox&w=${encodeURIComponent(kw)}&encoding=utf8&rformat=json`
    const resp = await httpGetText(url, { 'Referer': 'http://www.kuwo.cn/' })
    let parsed: KwSuggestResp
    try {
      parsed = JSON.parse(resp.body) as KwSuggestResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'suggest parse failed: %{public}s', resp.body.substring(0, 200))
      return []
    }
    // 新版返回 data.WORDITEMS，旧版返回顶层 WORDITEMS
    let items: KwSuggestItem[] | undefined = parsed.WORDITEMS
    if (items == undefined && parsed.data != undefined) {
      items = parsed.data.WORDITEMS
    }
    if (items == undefined) {
      return []
    }
    const result: string[] = []
    for (let i = 0; i < items.length; i++) {
      const word = items[i].RELWORD ?? ''
      if (word.length > 0) {
        result.push(word)
      }
    }
    return result
  }

}