/**
 * 网易云(wy)音源适配器 — implements SourceAdapter（对齐上游 `src/core/apiSource.ts` 的源注册机制）
 * import 本模块即完成 SourceRegistry 注册（import 侧注册，幂等）；
 * PlayerKernel / LyricManager 已 import 本模块，无需在 EntryAbility 显式注册。
 */
import { BusinessError } from '@kit.BasicServicesKit'
import { NormalizedError } from '../../utils/HttpUtil'
import { SourceAdapter, SourceRegistry } from '../MusicSource'
import { MusicInfo, MusicInfoMetaOnline, LyricInfo, isLocalInfo } from '../../model/MusicInfo'
import { WyApi } from './WyApi'

/** 业务错误码：音源参数缺失（songId 取不到等） */
const ERR_WY_SOURCE_INVALID = 2300004

class WySourceImpl implements SourceAdapter {
  readonly id: string = 'wy'

  async search(keyword: string): Promise<MusicInfo[]> {
    return WyApi.search(keyword)
  }

  async getMusicUrl(music: MusicInfo, quality: string): Promise<string> {
    if (isLocalInfo(music.meta)) {
      throw new NormalizedError(ERR_WY_SOURCE_INVALID, 'wy: music is local')
    }
    return WyApi.getMusicUrl(music, quality)
  }

  async suggest(keyword: string): Promise<string[]> {
    return WyApi.suggest(keyword)
  }

  async getLyric(music: MusicInfo): Promise<LyricInfo> {
    if (isLocalInfo(music.meta)) {
      return { lyric: '' }
    }
    return WyApi.getLyric(music)
  }
}

export const WySource: SourceAdapter = new WySourceImpl()

// import 侧注册：模块首次加载时执行（重复 import 仅执行一次，Map.set 幂等）
SourceRegistry.register(WySource)