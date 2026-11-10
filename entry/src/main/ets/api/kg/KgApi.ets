/**
 * 酷狗(kg)在线音源 API — 对齐上游 lx-music-mobile `src/utils/musicSdk/kg/`
 *  - musicSearch.js: GET songsearch.kugou.com/song_search_v2 → { error_code:0, data:{ lists } }
 *    字段：SongName/Singers/AlbumName/AlbumID/Audioid/Duration/FileHash(+HQ/SQ/Res)/Grp
 *  - musicUrl:       GET wwwapi.kugou.com/play/songinfo（web 签名，上游 v1.8 移除内置直链，
 *    此处按上游保留的 signatureParams 算法实现，社区验证方案）→ { data: { play_url } }
 *  - lyric.js:       lyrics.kugou.com/search → candidates[0] → download(fmt=lrc)
 *    （强制 fmt=lrc 取标准 LRC，规避 KRC 的 zlib 解码；headers 对齐上游 KG-RC/KG-THash/UA）
 * 响应做防御式解析：字段缺失/结构变化 → 空数组/空串（不抛错）；
 * 网络层错误由 HttpUtil 抛归一 BusinessError，交由调用方 catch 提示。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { MusicInfo, MusicInfoMetaOnline, QualityInfo, LyricInfo } from '../../model/MusicInfo'
import { formatTime } from '../../utils/FormatUtil'
import { httpGetText, ERR_HTTP_REQUEST_FAILED, NormalizedError } from '../../utils/HttpUtil'
import { KgSign } from './KgSign'

const TAG = 'KgApi'
const DOMAIN = 0x0001

const SEARCH_URL = 'https://songsearch.kugou.com/song_search_v2'
const MUSIC_URL_API = 'https://wwwapi.kugou.com/play/songinfo'
const LYRIC_SEARCH_URL = 'http://lyrics.kugou.com/search'
const LYRIC_DOWNLOAD_URL = 'http://lyrics.kugou.com/download'

/** 搜索每页数量（对齐上游 musicSearch.limit） */
const SEARCH_LIMIT = 30

/** 歌词接口固定 headers（对齐上游 lyric.js） */
const LYRIC_HEADERS: Record<string, string> = {
  'KG-RC': '1',
  'KG-THash': 'expand_search_manager.cpp:852736169:451',
  'User-Agent': 'KuGou2012-9020-ExpandSearchManager'
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

/** 去掉标题中的 HTML 标记（kg 搜索结果常含 <em> 高亮标签，对齐上游 decodeName） */
function decodeName(s: string): string {
  return s.replace(/<[^>]*>/g, '')
}

/** "03:55" → 秒（对齐上游 lyric.js getIntv，用于歌词搜索 timelength） */
function getIntv(interval: string | null): number {
  if (interval == undefined || interval == null || interval.length == 0) {
    return 0
  }
  const parts = interval.split(':')
  let total = 0
  let unit = 1
  for (let i = parts.length - 1; i >= 0; i--) {
    total += parseInt(parts[i], 10) * unit
    unit *= 60
  }
  return Number.isNaN(total) ? 0 : total
}

/* ---------------- 响应形状（防御式：全部字段可选） ---------------- */

interface KgSinger {
  name?: string
}

interface KgSongItem {
  SongName?: string
  Singers?: KgSinger[]
  AlbumName?: string
  AlbumID?: number
  Audioid?: number
  Duration?: number
  FileHash?: string
  FileSize?: number
  HQFileHash?: string
  HQFileSize?: number
  SQFileHash?: string
  SQFileSize?: number
  ResFileHash?: string
  ResFileSize?: number
  Grp?: KgSongItem[]
}

interface KgSearchData {
  lists?: KgSongItem[]
  total?: number
}

interface KgSearchResp {
  error_code?: number
  data?: KgSearchData
}

interface KgPlayData {
  play_url?: string
  status?: number
  error_code?: number
}

interface KgPlayResp {
  status?: number
  error_code?: number
  data?: KgPlayData
}

interface KgLyricCandidate {
  id?: string | number
  accesskey?: string
}

interface KgLyricSearchResp {
  status?: number
  candidates?: KgLyricCandidate[]
}

interface KgLyricDownloadResp {
  status?: number
  fmt?: string
  content?: string
}

interface KgSuggestItem {
  HintInfo?: string
}

interface KgSuggestGroup {
  RecordDatas?: KgSuggestItem[]
}

interface KgSuggestResp {
  status?: number
  error_code?: number
  /** 实际数据在 data 数组里（第一个分组含歌曲联想） */
  data?: KgSuggestGroup[]
}


export class KgApi {
  /** 关键词搜索 → MusicInfo[]（source='kg'，id='kg_'+audioid） */
  static async search(keyword: string): Promise<MusicInfo[]> {
    const kw = keyword.trim()
    if (kw.length == 0) {
      return []
    }
    const url = `${SEARCH_URL}?keyword=${encodeURIComponent(kw)}&page=1&pagesize=${SEARCH_LIMIT}` +
      `&userid=0&clientver=&platform=WebFilter&filter=2&iscorrection=1&privilege_filter=0&area_code=1`
    const resp = await httpGetText(url)
    let parsed: KgSearchResp
    try {
      parsed = JSON.parse(resp.body) as KgSearchResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'search parse failed: %{public}s', resp.body.substring(0, 200))
      return []
    }
    if (parsed.error_code != 0) {
      hilog.error(DOMAIN, TAG, 'search bad error_code: %{public}d', parsed.error_code ?? -1)
      throw makeBizError(`kg search error_code ${parsed.error_code ?? 'unknown'}`)
    }
    const data = parsed.data
    const lists = data != undefined ? data.lists : undefined
    if (lists == undefined || lists.length == 0) {
      return []
    }
    // 对齐上游 handleResult：顶层 + Grp 子项，Audioid+FileHash 去重
    const seen = new Set<string>()
    const result: MusicInfo[] = []
    for (let i = 0; i < lists.length; i++) {
      const item = lists[i]
      const music = KgApi.toMusicInfo(item)
      if (music != undefined) {
        const key = `${safeStr(item.Audioid?.toString())}_${safeStr(item.FileHash)}`
        if (!seen.has(key)) {
          seen.add(key)
          result.push(music)
        }
      }
      const grp = item.Grp
      if (grp != undefined) {
        for (let j = 0; j < grp.length; j++) {
          const child = grp[j]
          const childMusic = KgApi.toMusicInfo(child)
          if (childMusic != undefined) {
            const childKey = `${safeStr(child.Audioid?.toString())}_${safeStr(child.FileHash)}`
            if (!seen.has(childKey)) {
              seen.add(childKey)
              result.push(childMusic)
            }
          }
        }
      }
    }
    return result
  }

  private static toMusicInfo(item: KgSongItem): MusicInfo | undefined {
    const audioid = item.Audioid
    const hash = safeStr(item.FileHash)
    const name = decodeName(safeStr(item.SongName)).trim()
    if (typeof audioid != 'number' || hash.length == 0 || name.length == 0) {
      return undefined
    }
    const qualitys: QualityInfo[] = []
    if (item.FileSize != undefined && item.FileSize != 0) {
      const q: QualityInfo = { type: '128k', size: sizeFormate(item.FileSize), hash: safeStr(item.FileHash) }
      qualitys.push(q)
    }
    if (item.HQFileSize != undefined && item.HQFileSize != 0) {
      const q: QualityInfo = { type: '320k', size: sizeFormate(item.HQFileSize), hash: safeStr(item.HQFileHash) }
      qualitys.push(q)
    }
    if (item.SQFileSize != undefined && item.SQFileSize != 0) {
      const q: QualityInfo = { type: 'flac', size: sizeFormate(item.SQFileSize), hash: safeStr(item.SQFileHash) }
      qualitys.push(q)
    }
    if (item.ResFileSize != undefined && item.ResFileSize != 0) {
      const q: QualityInfo = { type: 'flac24bit', size: sizeFormate(item.ResFileSize), hash: safeStr(item.ResFileHash) }
      qualitys.push(q)
    }
    if (qualitys.length == 0) {
      const q: QualityInfo = { type: '128k', size: null, hash: hash }
      qualitys.push(q)
    }
    const singers: string[] = []
    const singerList = item.Singers
    if (singerList != undefined) {
      for (let i = 0; i < singerList.length; i++) {
        const singerName = safeStr(singerList[i].name).trim()
        if (singerName.length > 0) {
          singers.push(singerName)
        }
      }
    }
    const meta: MusicInfoMetaOnline = {
      songId: `${audioid}`,
      albumName: decodeName(safeStr(item.AlbumName)).trim(),
      picUrl: null,
      albumId: item.AlbumID != undefined ? `${item.AlbumID}` : undefined,
      qualitys: qualitys
    }
    const music: MusicInfo = {
      id: `kg_${audioid}`,
      name: name,
      singer: singers.join('、'),
      source: 'kg',
      interval: typeof item.Duration == 'number' && item.Duration > 0 ? formatTime(item.Duration) : null,
      meta: meta
    }
    return music
  }

  /** music + quality → 可播放直链；取不到（VIP/无版权/签名失效）返回空串（调用方走失败路径） */
  static async getMusicUrl(music: MusicInfo, quality: string): Promise<string> {
    const meta = music.meta as MusicInfoMetaOnline
    const qualitys = meta.qualitys
    let hash = ''
    if (qualitys != undefined) {
      for (let i = 0; i < qualitys.length; i++) {
        if (qualitys[i].type == quality && qualitys[i].hash != undefined) {
          hash = qualitys[i].hash as string
          break
        }
      }
      if (hash.length == 0 && qualitys.length > 0 && qualitys[0].hash != undefined) {
        hash = qualitys[0].hash as string
      }
    }
    if (hash.length == 0) {
      hilog.error(DOMAIN, TAG, 'no hash for quality %{public}s', quality)
      return ''
    }
    const clienttime = Math.floor(Date.now() / 1000)
    const mid = await KgSign.midFromTimestamp(clienttime)
    const albumId = meta.albumId != undefined ? meta.albumId : ''
    // 签名参数串（key 自身不参与签名；sort 按 'k=v' 整串排序，由 KgSign 处理）
    const signParams = `hash=${hash}&appid=1014&mid=${mid}&platid=4&srcappid=2919` +
      `&clientver=20000&clienttime=${clienttime}&uuid=${mid}&dfid=-&encode_album_id=${albumId}`
    const key = await KgSign.signatureParams(signParams, 'web')
    const url = `${MUSIC_URL_API}?${signParams}&key=${key}`
    const resp = await httpGetText(url)
    let parsed: KgPlayResp
    try {
      parsed = JSON.parse(resp.body) as KgPlayResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'musicUrl parse failed: hash=%{public}s', hash.substring(0, 8))
      return ''
    }
    if (parsed.status != 1 || parsed.error_code != 0) {
      hilog.error(DOMAIN, TAG, 'musicUrl bad status: %{public}d err=%{public}d hash=%{public}s',
        parsed.status ?? -1, parsed.error_code ?? -1, hash.substring(0, 8))
      throw makeBizError(`kg musicUrl status ${parsed.status ?? 'unknown'}`)
    }
    const data = parsed.data
    const playUrl = data != undefined ? data.play_url : undefined
    if (playUrl == undefined || playUrl.trim().length == 0) {
      hilog.error(DOMAIN, TAG, 'play_url empty (vip/copyright?): hash=%{public}s', hash.substring(0, 8))
      return ''
    }
    return playUrl.trim()
  }

  /** music → 歌词（search → download fmt=lrc → base64 解码）；无歌词返回 { lyric: '' } */
  static async getLyric(music: MusicInfo): Promise<LyricInfo> {
    const meta = music.meta as MusicInfoMetaOnline
    const qualitys = meta.qualitys
    let hash = ''
    if (qualitys != undefined && qualitys.length > 0 && qualitys[0].hash != undefined) {
      hash = qualitys[0].hash as string
    }
    const timelength = getIntv(music.interval) * 1000
    const searchUrl = `${LYRIC_SEARCH_URL}?ver=1&man=yes&client=pc` +
      `&keyword=${encodeURIComponent(music.name)}&hash=${hash}&timelength=${timelength}&lrctxt=1`
    const searchResp = await httpGetText(searchUrl, LYRIC_HEADERS)
    let parsedSearch: KgLyricSearchResp
    try {
      parsedSearch = JSON.parse(searchResp.body) as KgLyricSearchResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'lyric search parse failed')
      return { lyric: '' }
    }
    const candidates = parsedSearch.candidates
    if (candidates == undefined || candidates.length == 0) {
      return { lyric: '' }
    }
    const first = candidates[0]
    const id = first.id
    const accessKey = safeStr(first.accesskey)
    if (id == undefined || accessKey.length == 0) {
      return { lyric: '' }
    }
    // 强制 fmt=lrc：服务端将 KRC 转换为标准 LRC，规避 zlib 解码
    const downloadUrl = `${LYRIC_DOWNLOAD_URL}?ver=1&client=pc&id=${id}&accesskey=${encodeURIComponent(accessKey)}&fmt=lrc&charset=utf8`
    const downloadResp = await httpGetText(downloadUrl, LYRIC_HEADERS)
    let parsedDownload: KgLyricDownloadResp
    try {
      parsedDownload = JSON.parse(downloadResp.body) as KgLyricDownloadResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'lyric download parse failed: id=%{public}s', `${id}`)
      return { lyric: '' }
    }
    const content = parsedDownload.content
    if (parsedDownload.fmt != 'lrc' || content == undefined || content.length == 0) {
      hilog.error(DOMAIN, TAG, 'lyric content empty: fmt=%{public}s', safeStr(parsedDownload.fmt))
      return { lyric: '' }
    }
    const bytes = new util.Base64Helper().decodeSync(content)
    const decoder = new util.TextDecoder('utf-8')
    const lyric = decoder.decodeToString(bytes)
    if (lyric.trim().length == 0) {
      return { lyric: '' }
    }
    const info: LyricInfo = { lyric: lyric }
    return info
  }

  /**
   * 搜索联想（对齐 lx-music-desktop kg/tipSearch.js）：
   * GET https://searchtip.kugou.com/getSearchTip?MusicTipCount=10&keyword=<关键词>
   * → [0].RecordDatas[].HintInfo
   */
  static async suggest(keyword: string): Promise<string[]> {
    const kw = keyword.trim()
    if (kw.length === 0) {
      return []
    }
    const url = `https://searchtip.kugou.com/getSearchTip?MusicTipCount=10&keyword=${encodeURIComponent(kw)}`
    const resp = await httpGetText(url, { 'referer': 'https://www.kugou.com/' })
    let parsed: KgSuggestResp
    try {
      parsed = JSON.parse(resp.body) as KgSuggestResp
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'suggest parse failed: %{public}s', resp.body.substring(0, 200))
      return []
    }
    // 顶层是对象：{ status, data: [{ RecordDatas: [...] }] }
    const groups: KgSuggestGroup[] = parsed.data ?? []
    if (groups.length === 0) {
      return []
    }
    const records: KgSuggestItem[] = groups[0].RecordDatas ?? []
    const result: string[] = []
    for (let i = 0; i < records.length; i++) {
      const word = records[i].HintInfo ?? ''
      if (word.length > 0) {
        result.push(word)
      }
    }
    return result
  }

}