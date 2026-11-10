/**
 * 咪咕音乐(mg)在线音源 API — 对齐上游 lx-music-mobile `src/utils/musicSdk/mg/`
 *  - musicSearch.js: GET jadeite.migu.cn/music_search/v3/search/searchAll（md5 签名 headers），
 *    code==='000000'；songResultData.resultList 为二维数组，按 copyrightId 去重
 *    audioFormats.formatType：PQ→128k / HQ→320k / SQ→flac / ZQ24→flac24bit（size=asize??isize）
 *    签名：sign = md5(text + MD5SIG + YYAPP + deviceId + timestamp)（deviceId 固定，对齐上游 createSignature）
 *  - musicUrl: 上游 v1.8 已移除内置直链（走自定义源），此处按 listen1 社区验证方案实现：
 *    GET MIGUM3.0/strategy/pc/listen/v1.0?copyrightId=&contentId=&toneFlag=（PQ/HQ/SQ/ZQ）
 *    → data.url（'//' 前缀补 https:，'+' 替换 %2B）
 *  - lyric.js: lrcUrl/trcUrl 直取 LRC 文本（Referer/UA/channel 对齐上游 getText）；
 *    URL 缺失时二次查询 resourceinfo.do（POST resourceId=copyrightId）补全；
 *    mrcUrl 逐字歌词需 TEA 解密，首版降级跳过（与 kg KRC 决策一致）
 * 响应做防御式解析：字段缺失/结构变化 → 空数组/空串（不抛错）；
 * 网络层错误由 HttpUtil 抛归一 BusinessError，交由调用方 catch 提示。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { MusicInfo, MusicInfoMetaOnline, QualityInfo, LyricInfo } from '../../model/MusicInfo'
import { formatTime } from '../../utils/FormatUtil'
import { httpGetText, httpPostForm, ERR_HTTP_REQUEST_FAILED, NormalizedError } from '../../utils/HttpUtil'
import { md5Hex } from '../../utils/CryptoUtil'

const TAG = 'MgApi'
const DOMAIN = 0x0001

const SEARCH_URL = 'https://jadeite.migu.cn/music_search/v3/search/searchAll'
const LISTEN_URL = 'https://app.c.nf.migu.cn/MIGUM3.0/strategy/pc/listen/v1.0'
const RESOURCE_INFO_URL = 'https://c.musicapp.migu.cn/MIGUM2.0/v1.0/content/resourceinfo.do'

/** 搜索每页数量（上游 mg musicSearch.limit=20，取 30 与其他源一致） */
const SEARCH_LIMIT = 30

/** 签名常量（对齐上游 createSignature：appId 证书 md5 + yyapp2 签名 + 固定 deviceId） */
const SIGN_MD5 = '6cdc72a439cef99a3418d2a78aa28c73'
const SIGN_YYAPP = 'yyapp2d16148780a1dcc7408e06336b98cfd50'
const DEVICE_ID = '963B7AA0D21511ED807EE5846EC87D20'

const SEARCH_HEADERS: Record<string, string> = {
  'uiVersion': 'A_music_3.6.1',
  'deviceId': DEVICE_ID,
  'channel': '0146921',
  'User-Agent': 'Mozilla/5.0 (Linux; U; Android 11.0.0; zh-cn; MI 11 Build/OPR1.170623.032) AppleWebKit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30'
}

const LYRIC_HEADERS: Record<string, string> = {
  'Referer': 'https://app.c.nf.migu.cn/',
  'channel': '0146921',
  'User-Agent': 'Mozilla/5.0 (Linux; Android 5.1.1; Nexus 6 Build/LYZ28E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Mobile Safari/537.36'
}

const LISTEN_HEADERS: Record<string, string> = {
  'channel': '0146951',
  'uid': '1234'
}

/** 直链 toneFlag 映射（对齐 listen1 bootstrap_track） */
function toneFlagOf(quality: string): string {
  if (quality == '320k') {
    return 'HQ'
  }
  if (quality == 'flac') {
    return 'SQ'
  }
  if (quality == 'flac24bit') {
    return 'ZQ'
  }
  return 'PQ'
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

/* ---------------- 响应形状（防御式：全部字段可选） ---------------- */

interface MgAudioFormat {
  formatType?: string
  asize?: number
  isize?: number
}

interface MgSinger {
  name?: string
}

interface MgSongItem {
  songId?: string | number
  copyrightId?: string
  contentId?: string
  name?: string
  songName?: string
  album?: string
  albumId?: string | number
  singerList?: MgSinger[]
  duration?: number
  audioFormats?: MgAudioFormat[]
  img1?: string
  img2?: string
  img3?: string
  lrcUrl?: string
  mrcurl?: string
  trcUrl?: string
}

interface MgSongResultData {
  resultList?: MgSongItem[][]
  totalCount?: number
}

interface MgSearchResp {
  code?: string
  info?: string
  songResultData?: MgSongResultData
}

interface MgListenData {
  url?: string
  playUrl?: string
}

interface MgListenResp {
  code?: string
  data?: MgListenData
}

interface MgResourceInfoResp {
  resource?: MgSongItem[]
}

/** 搜索签名（对齐上游 createSignature：md5(text + MD5SIG + YYAPP + deviceId + ts)） */
async function searchSign(text: string, ts: string): Promise<string> {
  return md5Hex(`${text}${SIGN_MD5}${SIGN_YYAPP}${DEVICE_ID}${ts}`)
}

/** resourceinfo.do：按 copyrightId 查歌曲详情（contentId/歌词地址补全） */
async function fetchResourceInfo(copyrightId: string): Promise<MgSongItem | undefined> {
  const url = `${RESOURCE_INFO_URL}?resourceType=2`
  const form: Record<string, string> = { 'resourceId': copyrightId }
  const resp = await httpPostForm(url, form)
  let parsed: MgResourceInfoResp
  try {
    parsed = JSON.parse(resp.body) as MgResourceInfoResp
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'resourceinfo parse failed: %{public}s', copyrightId)
    return undefined
  }
  const resource = parsed.resource
  if (resource == undefined || resource.length == 0) {
    return undefined
  }
  return resource[0]
}

interface MgSuggestItem {
  name?: string
  singerName?: string
}

interface MgSuggestResp {
  songs?: MgSuggestItem[]
}


export class MgApi {
  /** 关键词搜索 → MusicInfo[]（source='mg'，id='mg_'+songId，copyrightId 去重） */
  static async search(keyword: string): Promise<MusicInfo[]> {
    const kw = keyword.trim()
    if (kw.length == 0) {
      return []
    }
    const ts = `${Date.now()}`
    const sign = await searchSign(kw, ts)
    const searchSwitch = encodeURIComponent('{"song":1,"album":0,"singer":0,"tagSong":1,"mvSong":0,"bestShow":1,"songlist":0,"lyricSong":0}')
    const url = `${SEARCH_URL}?isCorrect=0&isCopyright=1&searchSwitch=${searchSwitch}` +
      `&pageSize=${SEARCH_LIMIT}&text=${encodeURIComponent(kw)}&pageNo=1&sort=0&sid=USS`
    const headers: Record<string, string> = {
      'timestamp': ts,
      'sign': sign
    }
    const hKeys = Object.keys(SEARCH_HEADERS)
    for (let i = 0; i < hKeys.length; i++) {
      headers[hKeys[i]] = SEARCH_HEADERS[hKeys[i]]
    }
    const resp = await httpGetText(url, headers)
    let parsed: MgSearchResp
    try {
      parsed = JSON.parse(resp.body) as MgSearchResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'search parse failed: %{public}s', resp.body.substring(0, 200))
      return []
    }
    if (parsed.code != '000000') {
      hilog.error(DOMAIN, TAG, 'search bad code: %{public}s info=%{public}s', safeStr(parsed.code), safeStr(parsed.info))
      throw makeBizError('mg search failed')
    }
    const songResultData = parsed.songResultData
    const resultList = songResultData != undefined ? songResultData.resultList : undefined
    if (resultList == undefined || resultList.length == 0) {
      return []
    }
    // 对齐上游 filterData：二维数组展开 + copyrightId 去重
    const seen = new Set<string>()
    const result: MusicInfo[] = []
    for (let i = 0; i < resultList.length; i++) {
      const group = resultList[i]
      if (group == undefined) {
        continue
      }
      for (let j = 0; j < group.length; j++) {
        const music = MgApi.toMusicInfo(group[j])
        if (music == undefined) {
          continue
        }
        const meta = music.meta as MusicInfoMetaOnline
        const cpId = safeStr(meta.copyrightId)
        if (cpId.length == 0 || seen.has(cpId)) {
          continue
        }
        seen.add(cpId)
        result.push(music)
      }
    }
    return result
  }

  private static toMusicInfo(item: MgSongItem): MusicInfo | undefined {
    const songId = item.songId
    const copyrightId = safeStr(item.copyrightId)
    const name = safeStr(item.name != undefined ? item.name : item.songName).trim()
    if (songId == undefined || copyrightId.length == 0 || name.length == 0) {
      return undefined
    }
    // 对齐上游 filterData：PQ→128k / HQ→320k / SQ→flac / ZQ24→flac24bit
    const qualitys: QualityInfo[] = []
    const formats = item.audioFormats
    if (formats != undefined) {
      for (let i = 0; i < formats.length; i++) {
        const fmt = formats[i]
        const size = sizeFormate(fmt.asize != undefined ? fmt.asize : fmt.isize)
        let type: string | null = null
        if (fmt.formatType == 'PQ') {
          type = '128k'
        } else if (fmt.formatType == 'HQ') {
          type = '320k'
        } else if (fmt.formatType == 'SQ') {
          type = 'flac'
        } else if (fmt.formatType == 'ZQ24') {
          type = 'flac24bit'
        }
        if (type == null) {
          continue
        }
        const q: QualityInfo = { type: type, size: size }
        qualitys.push(q)
      }
    }
    if (qualitys.length == 0) {
      return undefined
    }
    // 对齐上游 img：img3||img2||img1，无 http 前缀补 d.musicapp.migu.cn
    let picUrl = safeStr(item.img3 != undefined ? item.img3 : (item.img2 != undefined ? item.img2 : item.img1))
    if (picUrl.length > 0 && !/https?:/.test(picUrl)) {
      picUrl = `http://d.musicapp.migu.cn${picUrl}`
    }
    const singers: string[] = []
    const singerList = item.singerList
    if (singerList != undefined) {
      for (let i = 0; i < singerList.length; i++) {
        const singerName = safeStr(singerList[i].name).trim()
        if (singerName.length > 0) {
          singers.push(singerName)
        }
      }
    }
    const songIdStr = `${songId}`
    const meta: MusicInfoMetaOnline = {
      songId: songIdStr,
      albumName: safeStr(item.album).trim(),
      picUrl: picUrl.length > 0 ? picUrl : null,
      albumId: item.albumId != undefined ? `${item.albumId}` : undefined,
      songmid: songIdStr,
      copyrightId: copyrightId,
      contentId: safeStr(item.contentId),
      lrcUrl: safeStr(item.lrcUrl),
      mrcUrl: safeStr(item.mrcurl),
      trcUrl: safeStr(item.trcUrl),
      qualitys: qualitys
    }
    const music: MusicInfo = {
      id: `mg_${songIdStr}`,
      name: name,
      singer: singers.join('、'),
      source: 'mg',
      interval: typeof item.duration == 'number' && item.duration > 0 ? formatTime(item.duration) : null,
      meta: meta
    }
    return music
  }

  /** music + quality → 可播放直链；取不到（VIP/无版权）返回空串（调用方走失败路径） */
  static async getMusicUrl(music: MusicInfo, quality: string): Promise<string> {
    const meta = music.meta as MusicInfoMetaOnline
    let copyrightId = safeStr(meta.copyrightId)
    let contentId = safeStr(meta.contentId)
    if (copyrightId.length == 0) {
      hilog.error(DOMAIN, TAG, 'no copyrightId')
      return ''
    }
    // listen1 方案需要 contentId；搜索结果缺失时二次查询补全
    if (contentId.length == 0) {
      const info = await fetchResourceInfo(copyrightId)
      if (info != undefined) {
        contentId = safeStr(info.contentId)
      }
    }
    const toneFlag = toneFlagOf(quality)
    const url = `${LISTEN_URL}?scene=&netType=01&resourceType=2&copyrightId=${encodeURIComponent(copyrightId)}` +
      `&contentId=${encodeURIComponent(contentId)}&toneFlag=${toneFlag}`
    const resp = await httpGetText(url, LISTEN_HEADERS)
    let parsed: MgListenResp
    try {
      parsed = JSON.parse(resp.body) as MgListenResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'musicUrl parse failed: %{public}s', copyrightId)
      return ''
    }
    if (parsed.code != '000000' && parsed.code != undefined) {
      hilog.error(DOMAIN, TAG, 'musicUrl bad code: %{public}s', safeStr(parsed.code))
      throw makeBizError('mg musicUrl failed')
    }
    const data = parsed.data
    let playUrl = data != undefined ? safeStr(data.url != undefined ? data.url : data.playUrl) : ''
    if (playUrl.length == 0) {
      hilog.error(DOMAIN, TAG, 'url empty (vip/copyright?): %{public}s', copyrightId)
      return ''
    }
    if (playUrl.startsWith('//')) {
      playUrl = `https:${playUrl}`
    }
    return playUrl.replace(/\+/g, '%2B')
  }

  /** music → 歌词（lrcUrl 直取 + trcUrl 翻译；缺失时 resourceinfo.do 补全）；无歌词返回 { lyric: '' } */
  static async getLyric(music: MusicInfo): Promise<LyricInfo> {
    const meta = music.meta as MusicInfoMetaOnline
    let lrcUrl = safeStr(meta.lrcUrl)
    let trcUrl = safeStr(meta.trcUrl)
    const copyrightId = safeStr(meta.copyrightId)
    if (copyrightId.length == 0) {
      return { lyric: '' }
    }
    if (lrcUrl.length == 0) {
      const info = await fetchResourceInfo(copyrightId)
      if (info != undefined) {
        lrcUrl = safeStr(info.lrcUrl)
        trcUrl = safeStr(info.trcUrl)
      }
    }
    if (lrcUrl.length == 0) {
      hilog.error(DOMAIN, TAG, 'no lrcUrl: %{public}s', copyrightId)
      return { lyric: '' }
    }
    const lrcResp = await httpGetText(lrcUrl, LYRIC_HEADERS)
    if (lrcResp.body.trim().length == 0) {
      return { lyric: '' }
    }
    const info: LyricInfo = { lyric: lrcResp.body }
    if (trcUrl.length > 0) {
      try {
        const trcResp = await httpGetText(trcUrl, LYRIC_HEADERS)
        if (trcResp.body.trim().length > 0) {
          info.tlyric = trcResp.body
        }
      } catch (e) {
        // 翻译歌词获取失败不影响主歌词
        hilog.error(DOMAIN, TAG, 'trc fetch failed: %{public}s', copyrightId)
      }
    }
    return info
  }

  /**
   * 搜索联想。
   *
   * 【注意】咪咕的公开联想接口（/v3/api/search/suggest 等）已下线（301 跳转到 v5 首页），
   * 这里返回空数组，由上层自动降级到本地曲库匹配，保证输入时仍有反馈。
   * 保留本方法是为了适配器接口统一。
   */
  static async suggest(keyword: string): Promise<string[]> {
    hilog.info(DOMAIN, TAG, 'mg suggest unavailable, fallback to local match')
    return []
  }

}