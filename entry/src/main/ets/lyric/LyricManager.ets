/**
 * 歌词管理 — 对齐上游 `src/core/lyric.ts`（当前播放歌词的加载与行定位）
 * MVP 歌词来源：沙箱 library/ 内与音频同名的 .lrc 文件（导入歌词时生成）。
 * 在线歌词：按优先级尝试（自定义脚本 > 内置音源）。
 *
 * 【模块边界】本模块只管「歌词从哪来、当前唱到哪一行」。
 * 音源访问统一走 core/source/SourceResolver，不再直接依赖 SourceEngine /
 * SourceRegistry / ListStore，因此不存在反向依赖。
 */
import { fileIo as fs } from '@kit.CoreFileKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MusicInfo, MusicInfoMetaLocal, isLocalInfo } from '../model/MusicInfo'
import { LyricParser, LyricLine, isPlaceholderLyric } from './LyricParser'
import { FileScanner } from '../utils/FileScanner'
import { SourceResolver } from '../core/source/SourceResolver'

const TAG = 'LyricManager'
const DOMAIN = 0x0001

class LyricManagerImpl {
  private lines: LyricLine[] = []
  private curMusicId: string = ''

  getLines(): LyricLine[] {
    return this.lines
  }

  /**
   * 加载指定歌曲歌词：查找 library/<同名>.lrc → 解析。
   * 返回行数组（无歌词返回空数组）。
   */
  async loadForMusic(music: MusicInfo | undefined): Promise<LyricLine[]> {
    if (music == undefined) {
      this.lines = []
      this.curMusicId = ''
      return this.lines
    }
    if (music.id == this.curMusicId) {
      return this.lines
    }
    this.lines = []
    this.curMusicId = music.id

    // 本地 .lrc 查找（仅对本地源有意义；在线源 meta 无 filePath，跳过）
    if (isLocalInfo(music.meta)) {
      try {
        const filePath = (music.meta as MusicInfoMetaLocal).filePath
        const slashIdx = filePath.lastIndexOf('/')
        const baseDir = slashIdx >= 0 ? filePath.substring(0, slashIdx) : ''
        const fileName = slashIdx >= 0 ? filePath.substring(slashIdx + 1) : filePath
        const dotIdx = fileName.lastIndexOf('.')
        const baseName = dotIdx > 0 ? fileName.substring(0, dotIdx) : fileName
        // 优先歌词目录（library/），其次音频同目录
        const candidates: string[] = [
          `${FileScanner.getLibraryDir()}/${baseName}.lrc`
        ]
        if (baseDir.length > 0 && baseDir != FileScanner.getLibraryDir()) {
          candidates.push(`${baseDir}/${baseName}.lrc`)
        }
        for (let i = 0; i < candidates.length; i++) {
          try {
            if (fs.accessSync(candidates[i])) {
              const content = fs.readTextSync(candidates[i], { encoding: 'utf-8' })
              this.lines = LyricParser.parse(content)
              hilog.info(DOMAIN, TAG, 'lyric loaded: %{public}s lines=%{public}d', candidates[i], this.lines.length)
              break
            }
          } catch (ignored) {
            // 文件不存在则尝试下一个候选
          }
        }
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'local lyric load failed: %{public}s', JSON.stringify(e))
      }
    }

    // 本地 .lrc 未找到 → 在线歌词：按优先级尝试
    if (this.lines.length == 0 && !isLocalInfo(music.meta)) {
      const resolver: SourceResolver = SourceResolver.getInstance()
      const priority: string[] = resolver.getPriority()
      for (let i = 0; i < priority.length; i++) {
        const sourceId: string = priority[i]
        try {
          const lyricText: string = await resolver.getLyricFrom(sourceId, music)
          // 占位歌词（「暂无歌词」+ 元信息）不算找到，继续换下一个音源
          if (lyricText.length > 0 && !isPlaceholderLyric(lyricText)) {
            this.lines = LyricParser.parse(lyricText)
            hilog.info(DOMAIN, TAG, 'online lyric loaded: source=%{public}s lines=%{public}d', sourceId, this.lines.length)
            return this.lines
          }
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'source %{public}s lyric failed: %{public}s', sourceId, JSON.stringify(e))
        }
      }
    }

    return this.lines
  }

  /** 由进度（秒）定位当前行 */
  findLineIndex(progressSec: number): number {
    return LyricParser.findLineIndex(this.lines, progressSec * 1000)
  }
}

export const LyricManager: LyricManagerImpl = new LyricManagerImpl()
