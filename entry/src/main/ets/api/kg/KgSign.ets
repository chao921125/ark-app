/**
 * 酷狗(kg)签名 — 对齐上游 lx-music-mobile `src/utils/musicSdk/kg/util.js` 的 signatureParams：
 *   keyparam: android='OIlwieks28dk2k092lksi2UIkp' / web='NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt'
 *   param_list = params.split('&') 后整体 sort()，sign = md5(keyparam + join('') + body + keyparam)
 * 直链（play/songinfo）采用 web 平台签名（社区验证方案，上游 v1.8 已移除内置直链，保留算法）。
 */
import { md5Hex } from '../../utils/CryptoUtil'

const KEY_ANDROID = 'OIlwieks28dk2k092lksi2UIkp'
const KEY_WEB = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt'

export class KgSign {
  /**
   * 对齐上游 signatureParams(params, platform, body)
   * @param params 'k1=v1&k2=v2&...' 形式的参数串（不含 key 本身）
   * @param platform 'android' | 'web'
   * @param body 附加签名体（默认空）
   */
  static async signatureParams(params: string, platform: string = 'android', body: string = ''): Promise<string> {
    const keyparam = platform == 'web' ? KEY_WEB : KEY_ANDROID
    const paramList: string[] = params.split('&')
    paramList.sort()
    const signSource = `${keyparam}${paramList.join('')}${body}${keyparam}`
    return md5Hex(signSource)
  }

  /** md5(ts) 形式的 mid/uuid（对齐上游直链请求约定） */
  static async midFromTimestamp(ts: number): Promise<string> {
    return md5Hex(`${ts}`)
  }
}