/**
 * 通用加密/哈希工具 — 供各在线音源（wy/kg 等）复用
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'

const HEX_CHARS = '0123456789abcdef'

export function bytesToHex(bytes: Uint8Array): string {
  let hex = ''
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i]
    hex += HEX_CHARS.charAt((b >> 4) & 0x0f)
    hex += HEX_CHARS.charAt(b & 0x0f)
  }
  return hex
}

/** MD5 摘要（hex 小写） */
export async function md5Hex(text: string): Promise<string> {
  const md = cryptoFramework.createMd('MD5')
  const encoder = new util.TextEncoder()
  const input: cryptoFramework.DataBlob = { data: encoder.encodeInto(text) }
  await md.update(input)
  const digest: cryptoFramework.DataBlob = await md.digest()
  return bytesToHex(digest.data)
}

/** SHA1 摘要（hex 小写） */
export async function sha1Hex(text: string): Promise<string> {
  const md = cryptoFramework.createMd('SHA1')
  const encoder = new util.TextEncoder()
  const input: cryptoFramework.DataBlob = { data: encoder.encodeInto(text) }
  await md.update(input)
  const digest: cryptoFramework.DataBlob = await md.digest()
  return bytesToHex(digest.data)
}

/** base64 → UTF-8 字符串（对齐上游 b64DecodeUnicode：atob + escape/unescape 的现代等价） */
export function base64DecodeUtf8(base64: string): string {
  const bytes = new util.Base64Helper().decodeSync(base64)
  const decoder = new util.TextDecoder('utf-8')
  return decoder.decodeToString(bytes)
}
