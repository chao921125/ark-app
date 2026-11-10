/**
 * QQ音乐(tx)签名 — 对齐上游 lx-music-mobile `src/utils/musicSdk/tx/utils/crypto.js` 的 zzcSign：
 *   hash = sha1(JSON.stringify(payload))（hex 40 字符）
 *   part1 = PART_1_INDEXES 逐位取字符（索引 40 越界取空串，与上游 join 对 undefined 的行为一致）
 *   part2 = PART_2_INDEXES 逐位取字符
 *   part3 = SCRAMBLE_VALUES[i] ^ hash 第 i 字节 → base64 去除 '/' '+' '='
 *   sign = ('zzc' + part1 + b64 + part2).toLowerCase()
 * 请求：POST https://u.y.qq.com/cgi-bin/musics.fcg?sign={sign}，body = 签名所用同一 JSON 串。
 */
import { sha1Hex } from '../../utils/CryptoUtil'
import { util } from '@kit.ArkTS'

const PART_1_INDEXES: number[] = [23, 14, 6, 36, 16, 40, 7, 19]
const PART_2_INDEXES: number[] = [16, 1, 32, 12, 19, 27, 8, 5]
const SCRAMBLE_VALUES: number[] =
  [89, 39, 179, 150, 218, 82, 58, 252, 177, 52, 186, 123, 120, 64, 242, 133, 143, 161, 121, 179]

export class TxSign {
  /** 对齐上游 zzcSign(text)；返回 url 可用的小写 sign（zzc 前缀） */
  static async zzcSign(text: string): Promise<string> {
    const hash = await sha1Hex(text)
    let part1 = ''
    for (let i = 0; i < PART_1_INDEXES.length; i++) {
      part1 += hash.charAt(PART_1_INDEXES[i])
    }
    let part2 = ''
    for (let i = 0; i < PART_2_INDEXES.length; i++) {
      part2 += hash.charAt(PART_2_INDEXES[i])
    }
    const part3 = new Uint8Array(SCRAMBLE_VALUES.length)
    for (let i = 0; i < SCRAMBLE_VALUES.length; i++) {
      const byteHex = hash.substring(i * 2, i * 2 + 2)
      part3[i] = SCRAMBLE_VALUES[i] ^ parseInt(byteHex, 16)
    }
    const base64 = new util.Base64Helper().encodeToStringSync(part3)
    const b64Part = base64.replace(/[/+=]/g, '')
    return `zzc${part1}${b64Part}${part2}`.toLowerCase()
  }
}