/**
 * 网易云(wy)请求加密 — 对齐上游 lx-music-mobile `src/utils/musicSdk/wy/utils/crypto.js`
 * （其实现源自 NeteaseCloudMusicApi util/crypto.js，语义等价还原为 ArkTS）：
 *  - eapi:  params = hex大写( AES-128-ECB-PKCS7("<path>-36cd479b6b5-<text>-36cd479b6b5-<md5>", 'e82ckenh8dichen8') )
 *  - weapi: params = b64( AES-CBC-PKCS7( utf8(b64(AES-CBC-PKCS7(text, presetKey))), secKey ) )
 *           encSecKey = hex( RSA-NoPadding( reverse(utf8(secKey)) 左补零至128字节 ) )，固定公钥
 * 依赖：@kit.CryptoArchitectureKit（MD5/AES）+ ArkTS bigint（RSA modPow）。
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'WyCrypto'
const DOMAIN = 0x0001

/** weapi 固定 AES 密钥（16 字节） */
const PRESET_KEY = '0CoJUm6Qyw8W8jud'
/** eapi 固定 AES 密钥（16 字节） */
const EAPI_KEY = 'e82ckenh8dichen8'
/** weapi 固定 IV（16 字节） */
const CBC_IV = '0102030405060708'
/** RSA 公钥指数（hex） */
const RSA_E_HEX = '010001'
/** RSA 公钥模数（hex，128 字节 = 1024 bit），来源：上游 crypto.js 内嵌 PEM 公钥 */
const RSA_N_HEX = 'e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7'

/** secKey 字符池：上游 String(Math.random()).substring(2,18) 即 16 位数字，此处等价生成 */
const SEC_CHAR_POOL = '0123456789'

const HEX_CHARS = '0123456789abcdef'

function utf8(text: string): Uint8Array {
  return new util.TextEncoder().encodeInto(text)
}

function b64Encode(bytes: Uint8Array): string {
  return new util.Base64Helper().encodeToStringSync(bytes, util.Type.BASIC)
}

function bytesToHex(bytes: Uint8Array): string {
  let hex = ''
  for (let i = 0; i < bytes.length; i++) {
    const b = bytes[i]
    hex += HEX_CHARS.charAt((b >> 4) & 0x0f)
    hex += HEX_CHARS.charAt(b & 0x0f)
  }
  return hex
}

function reverseBytes(bytes: Uint8Array): Uint8Array {
  const out = new Uint8Array(bytes.length)
  for (let i = 0; i < bytes.length; i++) {
    out[i] = bytes[bytes.length - 1 - i]
  }
  return out
}

/** 生成 16 位随机数字字符 secKey（等价上游 String(Math.random()).substring(2,18)，但保证长度恒为 16） */
function genSecKey(): string {
  let s = ''
  for (let i = 0; i < 16; i++) {
    s += SEC_CHAR_POOL.charAt(Math.floor(Math.random() * SEC_CHAR_POOL.length))
  }
  return s
}

/** 大数模幂：base^exp mod n（ArkTS bigint 实现，用于 RSA NoPadding 加密） */
function modPow(base: bigint, exp: bigint, n: bigint): bigint {
  let result: bigint = BigInt(1)
  let b: bigint = base % n
  let e: bigint = exp
  const zero = BigInt(0)
  const two = BigInt(2)
  while (e > zero) {
    if (e % two == BigInt(1)) {
      result = (result * b) % n
    }
    b = (b * b) % n
    e = e / two
  }
  return result
}

export class WyCrypto {
  /** MD5 摘要（hex 小写），eapi 的 digest 用 */
  static async md5Hex(text: string): Promise<string> {
    const md = cryptoFramework.createMd('MD5')
    const input: cryptoFramework.DataBlob = { data: utf8(text) }
    await md.update(input)
    const digest: cryptoFramework.DataBlob = await md.digest()
    return bytesToHex(digest.data)
  }

  /**
   * AES-128 加密（PKCS7），key 必须为 16 字节。
   * iv 非 null → CBC 模式；iv 为 null → ECB 模式。返回密文字节。
   */
  private static async aesEncrypt(data: Uint8Array, key: Uint8Array, iv: string | null): Promise<Uint8Array> {
    const gen = cryptoFramework.createSymKeyGenerator('AES128')
    const keyBlob: cryptoFramework.DataBlob = { data: key }
    const symKey = await gen.convertKey(keyBlob)
    let cipher: cryptoFramework.Cipher
    if (iv != null) {
      cipher = cryptoFramework.createCipher('AES128|CBC|PKCS7')
      const ivBlob: cryptoFramework.DataBlob = { data: utf8(iv) }
      const spec: cryptoFramework.IvParamsSpec = { algName: 'IvParamsSpec', iv: ivBlob }
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, spec)
    } else {
      cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7')
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null)
    }
    const input: cryptoFramework.DataBlob = { data: data }
    const out: cryptoFramework.DataBlob = await cipher.doFinal(input)
    return out.data
  }

  /**
   * RSA NoPadding 加密（公钥固定）：左补零至 128 字节 → m^65537 mod n → hex 左补零至 256 字符。
   * 上游 rsaEncrypt(buffer) = Buffer.concat([Buffer.alloc(128 - len), buffer]) 后 RSA NoPadding。
   */
  private static rsaNoPaddingHex(data: Uint8Array): string {
    const padded = new Uint8Array(128)
    padded.set(data, 128 - data.length)
    let m: bigint = BigInt(0)
    const radix = BigInt(256)
    for (let i = 0; i < padded.length; i++) {
      m = m * radix + BigInt(padded[i])
    }
    const e = BigInt(`0x${RSA_E_HEX}`)
    const n = BigInt(`0x${RSA_N_HEX}`)
    const r = modPow(m, e, n)
    let hex = r.toString(16)
    while (hex.length < 256) {
      hex = `0${hex}`
    }
    return hex
  }

  /**
   * eapi 表单（对齐上游 crypto.js eapi）：{ params: hex大写 }。
   * payload 为显式类型对象（调用方按接口构造，ArkTS 禁止裸字面量）。
   */
  static async eapi(path: string, payload: Object): Promise<Record<string, string>> {
    const text = JSON.stringify(payload)
    const message = `nobody${path}use${text}md5forencrypt`
    const digest = await WyCrypto.md5Hex(message)
    const data = `${path}-36cd479b6b5-${text}-36cd479b6b5-${digest}`
    const enc = await WyCrypto.aesEncrypt(utf8(data), utf8(EAPI_KEY), null)
    const form: Record<string, string> = { 'params': bytesToHex(enc).toUpperCase() }
    return form
  }

  /**
   * weapi 表单（对齐上游 crypto.js weapi）：{ params, encSecKey }。
   * payload 为显式类型对象（调用方按接口构造，ArkTS 禁止裸字面量）。
   */
  static async weapi(payload: Object): Promise<Record<string, string>> {
    const text = JSON.stringify(payload)
    const secKey = genSecKey()
    const enc1 = await WyCrypto.aesEncrypt(utf8(text), utf8(PRESET_KEY), CBC_IV)
    const enc2 = await WyCrypto.aesEncrypt(utf8(b64Encode(enc1)), utf8(secKey), CBC_IV)
    const form: Record<string, string> = {
      'params': b64Encode(enc2),
      'encSecKey': WyCrypto.rsaNoPaddingHex(reverseBytes(utf8(secKey)))
    }
    return form
  }

}