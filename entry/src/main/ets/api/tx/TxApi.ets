/**
 * QQ音乐(tx)在线音源 API — 对齐上游 lx-music-mobile `src/utils/musicSdk/tx/`
 *  - musicSearch.js: POST u.y.qq.com/cgi-bin/musics.fcg?sign=zzc…（module=music.search.SearchCgiService，
 *    method=DoSearchForQQMusicMobile），code!=0 重试（≤5）；结果 body.req.data.body.item_song
 *    字段：title/singer[]/album{id?,mid?,name?}/interval/file{media_mid,size_128mp3,size_320mp3,size_flac,size_hires}/id/mid
 *  - musicUrl: 上游 v1.8 已移除内置直链（走自定义源），此处按社区验证方案实现：
 *    module=vkey.GetVkeyServerBase64 method=CgiGetVkey → midurlinfo[0].purl → isure.stream 前缀拼接
 *    filename = {prefix}{songmid}{strMediaMid}.{ext}（M500/M800/F000/RS02 ← 128k/320k/flac/flac24bit）
 *  - lyric.js: GET c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid=…（Referer: y.qq.com）
 *    lyric/trans 为 base64(UTF-8) → 解码；失败返回 { lyric: '' }
 * 响应做防御式解析：字段缺失/结构变化 → 空数组/空串（不抛错）；
 * 网络层错误由 HttpUtil 抛归一 BusinessError，交由调用方 catch 提示。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { MusicInfo, MusicInfoMetaOnline, QualityInfo, LyricInfo } from '../../model/MusicInfo'
import { formatTime } from '../../utils/FormatUtil'
import { httpGetText, httpPostJson, ERR_HTTP_REQUEST_FAILED, NormalizedError } from '../../utils/HttpUtil'
import { base64DecodeUtf8 } from '../../utils/CryptoUtil'
import { TxSign } from './TxSign'

const TAG = 'TxApi'
const DOMAIN = 0x0001

const FCG_URL = 'https://u.y.qq.com/cgi-bin/musics.fcg'
const LYRIC_URL = 'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg'
const STREAM_URL_PREFIX = 'https://isure.stream.qqmusic.qq.com/'

/** 搜索每页数量（对齐上游 musicSearch.limit=50） */
const SEARCH_LIMIT = 30
/** 搜索 code!=0 最大重试次数（对齐上游 musicSearch retryNum>5） */
const SEARCH_MAX_RETRY = 5

const FCG_HEADERS: Record<string, string> = {
  'User-Agent': 'QQMusic 14090508(android 12)'
}

const LYRIC_HEADERS: Record<string, string> = {
  'Referer': 'https://y.qq.com/portal/player.html'
}

/** 直链质量前缀/扩展名映射（对齐社区源通用映射） */
interface FilenameParts {
  prefix: string
  ext: string
}

function filenameParts(quality: string): FilenameParts {
  if (quality == '320k') {
    const p: FilenameParts = { prefix: 'M800', ext: 'mp3' }
    return p
  }
  if (quality == 'flac') {
    const p: FilenameParts = { prefix: 'F000', ext: 'flac' }
    return p
  }
  if (quality == 'flac24bit') {
    const p: FilenameParts = { prefix: 'RS02', ext: 'flac' }
    return p
  }
  const p: FilenameParts = { prefix: 'M500', ext: 'mp3' }
  return p
}

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

/* ---------------- 请求 payload 形状（签名输入 = JSON.stringify，键序即书写序） ---------------- */

interface TxComm {
  ct: string
  cv: string
  v: string
  tmeAppID: string
  phonetype: string
  deviceScore: string
  devicelevel: string
  newdevicelevel: string
  rom: string
  os_ver: string
  OpenUDID: string
  OpenUDID2: string
  QIMEI36: string
  udid: string
  chid: string
  aid: string
  oaid: string
  taid: string
  tid: string
  wid: string
  uid: string
  sid: string
  modeSwitch: string
  teenMode: string
  ui_mode: string
  nettype: string
  v4ip: string
}

interface TxSearchParam {
  search_type: number
  searchid: string
  query: string
  page_num: number
  num_per_page: number
  highlight: number
  nqc_flag: number
  multi_zhida: number
  cat: number
  grp: number
  sin: number
  sem: number
}

interface TxSearchReq {
  module: string
  method: string
  param: TxSearchParam
}

interface TxSearchPayload {
  comm: TxComm
  req: TxSearchReq
}

interface TxVkeyParam {
  guid: string
  songmid: string[]
  songtype: number[]
  uin: string
  loginflag: number
  platform: string
  filename: string[]
}

interface TxVkeyReq {
  module: string
  method: string
  param: TxVkeyParam
}

interface TxVkeyPayload {
  comm: TxComm
  req: TxVkeyReq
}

function makeComm(): TxComm {
  const comm: TxComm = {
    ct: '11',
    cv: '14090508',
    v: '14090508',
    tmeAppID: 'qqmusic',
    phonetype: 'EBG-AN10',
    deviceScore: '553.47',
    devicelevel: '50',
    newdevicelevel: '20',
    rom: 'HuaWei/EMOTION/EmotionUI_14.2.0',
    os_ver: '12',
    OpenUDID: '0',
    OpenUDID2: '0',
    QIMEI36: '0',
    udid: '0',
    chid: '0',
    aid: '0',
    oaid: '0',
    taid: '0',
    tid: '0',
    wid: '0',
    uid: '0',
    sid: '0',
    modeSwitch: '6',
    teenMode: '0',
    ui_mode: '2',
    nettype: '1020',
    v4ip: ''
  }
  return comm
}

/* ---------------- 响应形状（防御式：全部字段可选） ---------------- */

interface TxSinger {
  name?: string
  mid?: string
}

interface TxAlbum {
  name?: string
  mid?: string
}

interface TxSongFile {
  media_mid?: string
  size_128mp3?: number
  size_320mp3?: number
  size_flac?: number
  size_hires?: number
}

interface TxSongItem {
  id?: string | number
  mid?: string
  title?: string
  singer?: TxSinger[]
  album?: TxAlbum
  interval?: number
  file?: TxSongFile
}

interface TxSearchBody {
  item_song?: TxSongItem[]
}

interface TxSearchData {
  body?: TxSearchBody
}

interface TxSearchReqData {
  code?: number
  data?: TxSearchData
}

interface TxSearchResp {
  code?: number
  req?: TxSearchReqData
}

interface TxMidUrlInfo {
  songmid?: string
  filename?: string
  purl?: string
}

interface TxVkeyData {
  midurlinfo?: TxMidUrlInfo[]
}

interface TxVkeyReqData {
  code?: number
  data?: TxVkeyData
}

interface TxVkeyResp {
  code?: number
  req?: TxVkeyReqData
}

interface TxLyricResp {
  code?: number
  lyric?: string
  trans?: string
}

/** 签名 + 请求：sign 输入与请求体使用同一 JSON 串（键序一致保证签名有效） */
async function signAndPost(body: string): Promise<string> {
  const sign = await TxSign.zzcSign(body)
  const resp = await httpPostJson(`${FCG_URL}?sign=${sign}`, body, FCG_HEADERS)
  return resp.body
}

interface TxSuggestItem {
  name?: string
  singer?: string
}

interface TxSuggestSongList {
  itemlist?: TxSuggestItem[]
}

interface TxSuggestSong {
  song?: TxSuggestSongList
}

interface TxSuggestResp {
  data?: TxSuggestSong
}


export class TxApi {
  /** 关键词搜索 → MusicInfo[]（source='tx'，id='tx_'+mid） */
  static async search(keyword: string): Promise<MusicInfo[]> {
    const kw = keyword.trim()
    if (kw.length == 0) {
      return []
    }
    let data: TxSearchData | undefined = undefined
    for (let retry = 0; retry <= SEARCH_MAX_RETRY; retry++) {
      const param: TxSearchParam = {
        search_type: 0,
        searchid: `${Math.floor(Math.random() * 10000000000)}`,
        query: kw,
        page_num: 1,
        num_per_page: SEARCH_LIMIT,
        highlight: 0,
        nqc_flag: 0,
        multi_zhida: 0,
        cat: 2,
        grp: 1,
        sin: 0,
        sem: 0
      }
      const payload: TxSearchPayload = {
        comm: makeComm(),
        req: {
          module: 'music.search.SearchCgiService',
          method: 'DoSearchForQQMusicMobile',
          param: param
        }
      }
      const respBody = await signAndPost(JSON.stringify(payload))
      let parsed: TxSearchResp
      try {
        parsed = JSON.parse(respBody) as TxSearchResp
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'search parse failed: %{public}s', respBody.substring(0, 200))
        return []
      }
      const reqData = parsed.req
      if (parsed.code != 0 || reqData == undefined || reqData.code != 0) {
        hilog.error(DOMAIN, TAG, 'search bad code: %{public}d req=%{public}d retry=%{public}d',
          parsed.code ?? -1, reqData != undefined ? reqData.code ?? -1 : -1, retry)
        if (retry == SEARCH_MAX_RETRY) {
          throw makeBizError('tx search failed')
        }
        continue
      }
      data = reqData.data
      break
    }
    const body = data != undefined ? data.body : undefined
    const rawList = body != undefined ? body.item_song : undefined
    if (rawList == undefined || rawList.length == 0) {
      return []
    }
    const result: MusicInfo[] = []
    for (let i = 0; i < rawList.length; i++) {
      const music = TxApi.toMusicInfo(rawList[i])
      if (music != undefined) {
        result.push(music)
      }
    }
    return result
  }

  private static toMusicInfo(item: TxSongItem): MusicInfo | undefined {
    const file = item.file
    const songmid = safeStr(item.mid)
    const name = safeStr(item.title).trim()
    if (file == undefined || safeStr(file.media_mid).length == 0 || songmid.length == 0 || name.length == 0) {
      return undefined
    }
    const qualitys: QualityInfo[] = []
    if (file.size_128mp3 != undefined && file.size_128mp3 != 0) {
      const q: QualityInfo = { type: '128k', size: sizeFormate(file.size_128mp3) }
      qualitys.push(q)
    }
    if (file.size_320mp3 != undefined && file.size_320mp3 != 0) {
      const q: QualityInfo = { type: '320k', size: sizeFormate(file.size_320mp3) }
      qualitys.push(q)
    }
    if (file.size_flac != undefined && file.size_flac != 0) {
      const q: QualityInfo = { type: 'flac', size: sizeFormate(file.size_flac) }
      qualitys.push(q)
    }
    if (file.size_hires != undefined && file.size_hires != 0) {
      const q: QualityInfo = { type: 'flac24bit', size: sizeFormate(file.size_hires) }
      qualitys.push(q)
    }
    if (qualitys.length == 0) {
      return undefined
    }
    const album = item.album
    const albumId = album != undefined ? safeStr(album.mid) : ''
    const singers: string[] = []
    const singerList = item.singer
    let firstSingerMid = ''
    if (singerList != undefined) {
      for (let i = 0; i < singerList.length; i++) {
        const singerName = safeStr(singerList[i].name).trim()
        if (singerName.length > 0) {
          singers.push(singerName)
        }
        if (firstSingerMid.length == 0) {
          const mid = safeStr(singerList[i].mid)
          if (mid.length > 0) {
            firstSingerMid = mid
          }
        }
      }
    }
    // 对齐上游 img：专辑封面优先，无专辑回退歌手封面
    let picUrl: string | null
    if (albumId.length == 0 || albumId == '空') {
      picUrl = firstSingerMid.length > 0
        ? `https://y.gtimg.cn/music/photo_new/T001R500x500M000${firstSingerMid}.jpg` : null
    } else {
      picUrl = `https://y.gtimg.cn/music/photo_new/T002R500x500M000${albumId}.jpg`
    }
    const meta: MusicInfoMetaOnline = {
      songId: item.id != undefined ? `${item.id}` : songmid,
      albumName: album != undefined ? safeStr(album.name).trim() : '',
      picUrl: picUrl,
      albumId: albumId.length > 0 ? albumId : undefined,
      songmid: songmid,
      strMediaMid: safeStr(file.media_mid),
      qualitys: qualitys
    }
    const music: MusicInfo = {
      id: `tx_${songmid}`,
      name: name,
      singer: singers.join('、'),
      source: 'tx',
      interval: typeof item.interval == 'number' && item.interval > 0 ? formatTime(item.interval) : null,
      meta: meta
    }
    return music
  }

  /** music + quality → 可播放直链；取不到（VIP/无版权/签名失效）返回空串（调用方走失败路径） */
  static async getMusicUrl(music: MusicInfo, quality: string): Promise<string> {
    const meta = music.meta as MusicInfoMetaOnline
    const songmid = safeStr(meta.songmid)
    if (songmid.length == 0) {
      hilog.error(DOMAIN, TAG, 'no songmid')
      return ''
    }
    const strMediaMid = safeStr(meta.strMediaMid)
    const parts = filenameParts(quality)
    const filename = `${parts.prefix}${songmid}${strMediaMid}.${parts.ext}`
    const guid = `${Math.floor(Math.random() * 10000000)}`
    const param: TxVkeyParam = {
      guid: guid,
      songmid: [songmid],
      songtype: [0],
      uin: '0',
      loginflag: 1,
      platform: '20',
      filename: [filename]
    }
    const payload: TxVkeyPayload = {
      comm: makeComm(),
      req: {
        module: 'vkey.GetVkeyServerBase64',
        method: 'CgiGetVkey',
        param: param
      }
    }
    const respBody = await signAndPost(JSON.stringify(payload))
    let parsed: TxVkeyResp
    try {
      parsed = JSON.parse(respBody) as TxVkeyResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'musicUrl parse failed: songmid=%{public}s', songmid)
      return ''
    }
    const reqData = parsed.req
    if (parsed.code != 0 || reqData == undefined || reqData.code != 0) {
      hilog.error(DOMAIN, TAG, 'musicUrl bad code: %{public}d req=%{public}d',
        parsed.code ?? -1, reqData != undefined ? reqData.code ?? -1 : -1)
      throw makeBizError('tx musicUrl failed')
    }
    const data = reqData.data
    const midurlinfo = data != undefined ? data.midurlinfo : undefined
    const purl = midurlinfo != undefined && midurlinfo.length > 0 ? safeStr(midurlinfo[0].purl) : ''
    if (purl.length == 0) {
      hilog.error(DOMAIN, TAG, 'purl empty (vip/copyright?): songmid=%{public}s', songmid)
      return ''
    }
    return `${STREAM_URL_PREFIX}${purl}`
  }

  /** music → 歌词（base64 解码，含翻译歌词 tlyric）；无歌词返回 { lyric: '' } */
  static async getLyric(music: MusicInfo): Promise<LyricInfo> {
    const meta = music.meta as MusicInfoMetaOnline
    const songmid = safeStr(meta.songmid)
    if (songmid.length == 0) {
      return { lyric: '' }
    }
    const url = `${LYRIC_URL}?songmid=${encodeURIComponent(songmid)}&g_tk=5381&loginUin=0&hostUin=0` +
      `&format=json&inCharset=utf8&outCharset=utf-8&platform=yqq`
    const resp = await httpGetText(url, LYRIC_HEADERS)
    let parsed: TxLyricResp
    try {
      parsed = JSON.parse(resp.body) as TxLyricResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'lyric parse failed: songmid=%{public}s', songmid)
      return { lyric: '' }
    }
    const lyricB64 = safeStr(parsed.lyric)
    if (parsed.code != 0 || lyricB64.length == 0) {
      return { lyric: '' }
    }
    const info: LyricInfo = { lyric: base64DecodeUtf8(lyricB64) }
    const transB64 = safeStr(parsed.trans)
    if (transB64.length > 0) {
      info.tlyric = base64DecodeUtf8(transB64)
    }
    return info
  }

  /**
   * 搜索联想（对齐 lx-music-desktop tx/tipSearch.js）：
   * GET https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?key=<关键词>&format=json
   * → data.song.itemlist[] → 「歌名 - 歌手」
   */
  static async suggest(keyword: string): Promise<string[]> {
    const kw = keyword.trim()
    if (kw.length === 0) {
      return []
    }
    const url = `https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg?is_xml=0&format=json&key=${encodeURIComponent(kw)}` +
      `&loginUin=0&hostUin=0&inCharset=utf8&outCharset=utf-8&notice=0&platform=yqq&needNewCode=0`
    const resp = await httpGetText(url, { 'Referer': 'https://y.qq.com/portal/player.html' })
    let parsed: TxSuggestResp
    try {
      parsed = JSON.parse(resp.body) as TxSuggestResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'suggest parse failed: %{public}s', resp.body.substring(0, 200))
      return []
    }
    const items: TxSuggestItem[] = parsed.data?.song?.itemlist ?? []
    const result: string[] = []
    for (let i = 0; i < items.length; i++) {
      const name = items[i].name ?? ''
      const singer = items[i].singer ?? ''
      if (name.length > 0) {
        result.push(singer.length > 0 ? `${name} - ${singer}` : name)
      }
    }
    return result
  }

}