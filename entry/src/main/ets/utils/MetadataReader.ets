/**
 * 本地音频元数据解析 — 对齐上游 react-native-local-media-metadata 的职责（四期接入）
 * 使用 AVMetadataExtractor（API 12）：标题/歌手/专辑/时长 + 专辑封面提取落盘（jpg）。
 * 全流程防御式：任何一步失败仅降级为空字段，不抛出、不阻塞导入。
 */
import { media } from '@kit.MediaKit'
import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'MetadataReader'
const DOMAIN = 0x0001

export interface AudioMetadata {
  title: string
  artist: string
  album: string
  /** 秒（解析失败为 0，由调用方回退到估算） */
  durationSec: number
  /** 封面落盘路径（未提取到为空串） */
  coverPath: string
}

class MetadataReaderImpl {
  /**
   * 解析音频文件元数据。
   * @param filePath 沙箱内音频文件路径
   * @param coverDest 封面输出路径（提取成功时写入 jpg）
   */
  async read(filePath: string, coverDest: string): Promise<AudioMetadata> {
    const result: AudioMetadata = { title: '', artist: '', album: '', durationSec: 0, coverPath: '' }
    let extractor: media.AVMetadataExtractor | undefined = undefined
    let fd = -1
    try {
      const stat = fs.statSync(filePath)
      fd = fs.openSync(filePath, fs.OpenMode.READ_ONLY).fd
      extractor = await media.createAVMetadataExtractor()
      extractor.fdSrc = { fd: fd, offset: 0, length: stat.size }
      const metadata = await extractor.fetchMetadata()
      result.title = this.str(metadata.title)
      result.artist = this.str(metadata.artist)
      result.album = this.str(metadata.album)
      const durationMs = parseInt(this.str(metadata.duration), 10)
      if (Number.isFinite(durationMs) && durationMs > 0) {
        result.durationSec = durationMs / 1000
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'fetchMetadata failed(%{public}s): %{public}s', filePath, JSON.stringify(e))
    }

    if (extractor != undefined) {
      try {
        const pixelMap = await extractor.fetchAlbumCover()
        if (pixelMap != undefined && (await this.saveCover(pixelMap, coverDest))) {
          result.coverPath = coverDest
        }
      } catch (e2) {
        hilog.warn(DOMAIN, TAG, 'fetchAlbumCover failed: %{public}s', JSON.stringify(e2))
      }
      try {
        await extractor.release()
      } catch (ignored) {
        // ignore
      }
      extractor = undefined
    }
    if (fd >= 0) {
      try {
        fs.closeSync(fd)
      } catch (ignored) {
        // ignore
      }
    }
    return result
  }

  private async saveCover(pixelMap: image.PixelMap, dest: string): Promise<boolean> {
    let packer: image.ImagePacker | undefined = undefined
    let file: fs.File | undefined = undefined
    try {
      // 本 SDK 的 ImagePacker 仅有 packToFile（写文件 fd），无 pack 缓冲区重载
      const options: image.PackingOption = { format: 'image/jpeg', quality: 90 }
      packer = image.createImagePacker()
      file = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      await packer.packToFile(pixelMap, file.fd, options)
      const stat = fs.statSync(dest)
      return stat.size > 0
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'saveCover failed: %{public}s', JSON.stringify(e))
      return false
    } finally {
      if (file != undefined) {
        try {
          fs.closeSync(file.fd)
        } catch (ignored) {
          // ignore
        }
      }
      if (packer != undefined) {
        try {
          await packer.release()
        } catch (ignored) {
          // ignore
        }
      }
      try {
        await pixelMap.release()
      } catch (ignored) {
        // ignore
      }
    }
  }

  private str(v: string | undefined): string {
    return v != undefined ? v : ''
  }
}

export const MetadataReader: MetadataReaderImpl = new MetadataReaderImpl()
