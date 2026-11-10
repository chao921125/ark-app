/**
 * QQ音乐(tx)音源适配器 — implements SourceAdapter（对齐上游 `src/core/apiSource.ts` 的源注册机制）
 * import 本模块即完成 SourceRegistry 注册（import 侧注册，幂等）；
 * PlayerKernel / LyricManager 已 import 本模块，无需在 EntryAbility 显式注册。
 */
import { BusinessError } from '@kit.BasicServicesKit'
import { NormalizedError } from '../../utils/HttpUtil'
import { SourceAdapter, SourceRegistry } from '../MusicSource'
import { MusicInfo, MusicInfoMetaOnline, LyricInfo, isLocalInfo } from '../../model/MusicInfo'
import { TxApi } from './TxApi'

/** 业务错误码：音源参数缺失（songmid 取不到等） */
const ERR_TX_SOURCE_INVALID = 2300006

class TxSourceImpl implements SourceAdapter {
  readonly id: string = 'tx'

  async search(keyword: string): Promise<MusicInfo[]> {
    return TxApi.search(keyword)
  }

  async getMusicUrl(music: MusicInfo, quality: string): Promise<string> {
    if (isLocalInfo(music.meta)) {
      throw new NormalizedError(ERR_TX_SOURCE_INVALID, 'tx: music is local')
    }
    return TxApi.getMusicUrl(music, quality)
  }

  async suggest(keyword: string): Promise<string[]> {
    return TxApi.suggest(keyword)
  }

  async getLyric(music: MusicInfo): Promise<LyricInfo> {
    if (isLocalInfo(music.meta)) {
      return { lyric: '' }
    }
    return TxApi.getLyric(music)
  }
}

export const TxSource: SourceAdapter = new TxSourceImpl()

// import 侧注册：模块首次加载时执行（重复 import 仅执行一次，Map.set 幂等）
SourceRegistry.register(TxSource)