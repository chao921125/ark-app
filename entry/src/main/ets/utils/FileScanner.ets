/**
 * 本地音乐导入 — 对齐上游 `src/core/music/local.ts`（本地源构建）与
 * react-native-local-media-metadata / react-native-fs 的职责。
 * 策略：复制音频/歌词到应用沙箱（规避 picker 临时授权过期），
 * 元数据用 AVMetadataExtractor 解析（标题/歌手/专辑/时长/封面落盘），失败回退文件名解析与时长估算。
 */
import { fileIo as fs } from '@kit.CoreFileKit'
import { picker } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MusicInfo, MusicInfoMetaLocal } from '../model/MusicInfo'
import { util } from '@kit.ArkTS'
import { NormalizedError } from './HttpUtil'
import { MetadataReader } from './MetadataReader'
import { parseNameFromFileName, getExt, hashString, formatTime, SUPPORTED_AUDIO_EXTS } from './FormatUtil'

const TAG = 'FileScanner'
const DOMAIN = 0x0001
const LIBRARY_DIR = 'library'

class FileScannerImpl {
  private libraryDir: string = ''

  init(context: common.Context): void {
    this.libraryDir = `${context.filesDir}/${LIBRARY_DIR}`
    if (!fs.accessSync(this.libraryDir)) {
      fs.mkdirSync(this.libraryDir, true)
    }
  }

  getLibraryDir(): string {
    return this.libraryDir
  }

  /** 拉起文件选择器（音频多选），返回所选 file uri */
  async pickAudioFiles(context: common.Context): Promise<string[]> {
    const docPicker = new picker.DocumentViewPicker()
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 50
    options.fileSuffixFilters = SUPPORTED_AUDIO_EXTS.map(e => `.${e}`)
    try {
      const uris = await docPicker.select(options)
      return uris
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'pickAudioFiles failed: %{public}s', JSON.stringify(err))
      return []
    }
  }

  /** 拉起文件选择器（歌词单选 .lrc） */
  async pickLyricFile(context: common.Context): Promise<string> {
    const docPicker = new picker.DocumentViewPicker()
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.fileSuffixFilters = ['.lrc']
    try {
      const uris = await docPicker.select(options)
      if (uris.length > 0) {
        return uris[0]
      }
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'pickLyricFile failed: %{public}s', JSON.stringify(err))
    }
    return ''
  }

  /** 拉起文件选择器（自定义源脚本单选 .js，三期） */
  async pickUserScript(context: common.Context): Promise<string> {
    const docPicker = new picker.DocumentViewPicker()
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.fileSuffixFilters = ['.js']
    try {
      const uris = await docPicker.select(options)
      if (uris.length > 0) {
        return uris[0]
      }
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'pickUserScript failed: %{public}s', JSON.stringify(err))
    }
    return ''
  }

  /** 读取所选文件文本（fd 方式读入缓冲，规避 uri 授权时效；本 SDK readTextSync 不支持 fd） */
  async readTextFromUri(uri: string): Promise<string> {
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
    try {
      const stat = fs.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buf)
      const decoder = new util.TextDecoder('utf-8')
      return decoder.decodeToString(new Uint8Array(buf))
    } finally {
      try {
        fs.closeSync(file.fd)
      } catch (ignored) {
        // ignore
      }
    }
  }

  /**
   * 把文本写入指定 uri（覆盖写）。用于备份导出：先经 DocumentViewPicker.save()
   * 取得目标文件 uri，再把序列化后的内容写进去。
   */
  async writeTextToUri(uri: string, text: string): Promise<void> {
    const file = fs.openSync(uri, fs.OpenMode.READ_WRITE)
    try {
      fs.truncateSync(file.fd, 0)
      const encoder = new util.TextEncoder('utf-8')
      const bytes: Uint8Array = encoder.encodeInto(text)
      fs.writeSync(file.fd, bytes.buffer)
      fs.fsyncSync(file.fd)
    } finally {
      try {
        fs.closeSync(file.fd)
      } catch (ignored) {
        // ignore
      }
    }
  }

  /** 选择一个保存目标（用于备份导出），返回 uri；用户取消返回空串 */
  async pickSaveTarget(context: common.Context, fileName: string): Promise<string> {
    const docPicker = new picker.DocumentViewPicker()
    const options = new picker.DocumentSaveOptions()
    options.newFileNames = [fileName]
    try {
      const uris = await docPicker.save(options)
      return uris.length > 0 ? uris[0] : ''
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'pick save target failed: %{public}s', JSON.stringify(e))
      return ''
    }
  }

  /** 选择一个 JSON 文件（用于备份导入） */
  async pickJsonFile(context: common.Context): Promise<string> {
    const docPicker = new picker.DocumentViewPicker()
    const options = new picker.DocumentSelectOptions()
    options.fileSuffixFilters = ['.json']
    try {
      const uris = await docPicker.select(options)
      return uris.length > 0 ? uris[0] : ''
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'pick json file failed: %{public}s', JSON.stringify(e))
      return ''
    }
  }

  /**
   * 导入音频：复制进沙箱 library/，解析文件名，返回 MusicInfo 列表。
   */
  async importAudio(uris: string[]): Promise<MusicInfo[]> {
    const result: MusicInfo[] = []
    for (let i = 0; i < uris.length; i++) {
      const uri = uris[i]
      try {
        const music = await this.importOne(uri)
        if (music != undefined) {
          result.push(music)
        }
      } catch (e) {
        const err = e as BusinessError
        hilog.error(DOMAIN, TAG, 'import %{public}s failed: %{public}s', uri, JSON.stringify(err))
      }
    }
    return result
  }

  /**
   * 导入歌词并绑定歌曲（以歌曲文件名命名 .lrc 存入 library/）。
   */
  async importLyricFor(music: MusicInfo, lyricUri: string): Promise<boolean> {
    try {
      const filePath = (music.meta as MusicInfoMetaLocal).filePath
      const baseName = this.baseNameOf(filePath)
      const dest = `${this.libraryDir}/${baseName}.lrc`
      fs.copyFileSync(lyricUri, dest)
      return true
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'importLyric failed: %{public}s', JSON.stringify(err))
      return false
    }
  }

  private async importOne(uri: string): Promise<MusicInfo | undefined> {
    const srcFd = fs.openSync(uri, fs.OpenMode.READ_ONLY)
    let fileName = ''
    try {
      const stat = fs.statSync(srcFd.fd)
      fileName = this.baseNameOf(uri)
      const ext = getExt(fileName)
      if (SUPPORTED_AUDIO_EXTS.indexOf(ext) < 0) {
        fs.closeSync(srcFd)
        return undefined
      }
      const uniqueName = `${Date.now()}_${this.sanitize(fileName)}`
      const destPath = `${this.libraryDir}/${uniqueName}`
      fs.copyFileSync(srcFd.fd, destPath)
      fs.closeSync(srcFd)
      const fileSize = stat.size

      // 元数据解析（标题/歌手/专辑/时长/封面），失败回退文件名解析
      const parsed = parseNameFromFileName(fileName)
      let name = parsed.name
      let singer = parsed.singer
      let albumName = '本地音乐'
      let interval = this.guessIntervalBySize(fileSize, ext)
      let picUrl: string | null = null
      try {
        const md = await MetadataReader.read(destPath, `${this.libraryDir}/${uniqueName}_cover.jpg`)
        if (md.title.length > 0) {
          name = md.title
        }
        if (md.artist.length > 0) {
          singer = md.artist
        }
        if (md.album.length > 0) {
          albumName = md.album
        }
        if (md.durationSec > 0) {
          interval = formatTime(md.durationSec)
        }
        if (md.coverPath.length > 0) {
          picUrl = md.coverPath
        }
      } catch (mdErr) {
        hilog.warn(DOMAIN, TAG, 'metadata read fallback to filename: %{public}s', JSON.stringify(mdErr))
      }

      const id = `local_${hashString(destPath)}`
      const meta: MusicInfoMetaLocal = {
        songId: destPath,
        albumName: albumName,
        picUrl: picUrl,
        filePath: destPath,
        ext: ext
      }
      const music: MusicInfo = {
        id: id,
        name: name,
        singer: singer,
        source: 'local',
        interval: interval,
        meta: meta
      }
      return music
    } catch (e) {
      try {
        fs.closeSync(srcFd)
      } catch (ignored) {
        // ignore
      }
      const err = e as BusinessError
      throw new NormalizedError(2300050, `import failed: ${err.message ?? 'unknown error'}`)
    }
  }

  /** 按比特率估算时长占位（仅展示用途，prepare 后由真实 duration 覆盖） */
  private guessIntervalBySize(size: number, ext: string): string | null {
    if (size <= 0) {
      return null
    }
    const bitrate = ext == 'flac' || ext == 'wav' ? 900 * 1024 : 128 * 1024
    const sec = Math.floor(size * 8 / bitrate)
    if (sec < 5 || sec > 3600 * 2) {
      return null
    }
    const mm = Math.floor(sec / 60)
    const ss = sec % 60
    return `${mm < 10 ? `0${mm}` : `${mm}`}:${ss < 10 ? `0${ss}` : `${ss}`}`
  }

  private baseNameOf(pathOrUri: string): string {
    let path = pathOrUri
    const qIdx = path.indexOf('?')
    if (qIdx >= 0) {
      path = path.substring(0, qIdx)
    }
    const slashIdx = Math.max(path.lastIndexOf('/'), path.lastIndexOf('%2F'))
    let name = slashIdx >= 0 ? path.substring(slashIdx + 1) : path
    name = decodeURIComponent(name)
    return name
  }

  private sanitize(name: string): string {
    return name.replace(/[\\/:*?"<>|]/g, '_')
  }
}

export const FileScanner: FileScannerImpl = new FileScannerImpl()