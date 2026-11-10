/**
 * PC 同步加密工具 — 对齐上游 `src/plugins/sync/utils.ts`
 *  - AES：aes-128-ecb（上游 native ECB_128_NoPadding 实际等效 PKCS7，同 wy eapi），key 为 base64(16 字节)
 *  - RSA：2048 位密钥对（客户端生成），OAEPWithSHA1AndMGF1Padding 解密；
 *    公钥以 SPKI DER base64 传输（等价上游去掉 PEM 头尾的 publicKey），私钥 PKCS8 DER base64
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { util } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { NormalizedError, ERR_HTTP_REQUEST_FAILED } from '../utils/HttpUtil'

const TAG = 'SyncCrypto'
const DOMAIN = 0x0001

function bytesToB64(bytes: Uint8Array): string {
  return new util.Base64Helper().encodeToStringSync(bytes)
}

function b64ToBytes(b64: string): Uint8Array {
  return new util.Base64Helper().decodeSync(b64)
}

export interface SyncRsaKeyPair {
  /** SPKI DER base64（等价上游去 PEM 头尾的 publicKey） */
  publicKey: string
  /** PKCS8 DER base64（本地保存用于解密响应） */
  privateKey: string
}

export class SyncCrypto {
  /** AES-128-ECB(PKCS7) 加密：text → base64 */
  static async aesEncrypt(text: string, b64Key: string): Promise<string> {
    const keyGen = cryptoFramework.createSymKeyGenerator('AES128')
    const symKey = await keyGen.convertKey({ data: b64ToBytes(b64Key) })
    const cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7')
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null)
    const encoder = new util.TextEncoder()
    const updateOut = await cipher.update({ data: encoder.encodeInto(text) })
    const finalOut = await cipher.doFinal(null)
    const all = new Uint8Array(updateOut.data.length + finalOut.data.length)
    all.set(updateOut.data, 0)
    all.set(finalOut.data, updateOut.data.length)
    return bytesToB64(all)
  }

  /** AES-128-ECB(PKCS7) 解密：base64 → text */
  static async aesDecrypt(b64Text: string, b64Key: string): Promise<string> {
    const keyGen = cryptoFramework.createSymKeyGenerator('AES128')
    const symKey = await keyGen.convertKey({ data: b64ToBytes(b64Key) })
    const cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7')
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, null)
    const updateOut = await cipher.update({ data: b64ToBytes(b64Text) })
    const finalOut = await cipher.doFinal(null)
    const all = new Uint8Array(updateOut.data.length + finalOut.data.length)
    all.set(updateOut.data, 0)
    all.set(finalOut.data, updateOut.data.length)
    const decoder = new util.TextDecoder('utf-8')
    return decoder.decodeToString(all)
  }

  /** 生成 RSA-2048 密钥对（客户端发起 codeAuth 时使用） */
  static async generateRsaKey(): Promise<SyncRsaKeyPair> {
    const keyGen = cryptoFramework.createAsyKeyGenerator('RSA2048')
    const pair = await keyGen.generateKeyPair()
    const pubB64 = bytesToB64(pair.pubKey.getEncoded().data)
    const priB64 = bytesToB64(pair.priKey.getEncoded().data)
    const pairOut: SyncRsaKeyPair = { publicKey: pubB64, privateKey: priB64 }
    return pairOut
  }

  /** RSA-OAEP(SHA1+MGF1_SHA1) 私钥解密：base64 → text（codeAuth 响应解密 KeyInfo） */
  static async rsaDecrypt(b64Text: string, b64PriKey: string): Promise<string> {
    const keyGen = cryptoFramework.createAsyKeyGenerator('RSA2048')
    const keyPair = await keyGen.convertKey(null, { data: b64ToBytes(b64PriKey) })
    const priKey = keyPair.priKey
    const cipher = cryptoFramework.createCipher('RSA2048|OAEP|SHA1|MGF1_SHA1')
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, priKey, null)
    const finalOut = await cipher.doFinal({ data: b64ToBytes(b64Text) })
    const decoder = new util.TextDecoder('utf-8')
    return decoder.decodeToString(finalOut.data)
  }

  /** md5 → 前 16 字符 hex 作为 AES key（base64 化，对齐上游 codeAuth：key = toMD5(authCode).substring(0,16) 再 base64） */
  static async deriveKeyFromAuthCode(authCode: string): Promise<string> {
    const md = cryptoFramework.createMd('MD5')
    const encoder = new util.TextEncoder()
    await md.update({ data: encoder.encodeInto(authCode) })
    const digest = await md.digest()
    let hex = ''
    for (let i = 0; i < digest.data.length; i++) {
      hex += (digest.data[i] < 16 ? '0' : '') + digest.data[i].toString(16)
    }
    // 上游 Buffer.from(key).toString('base64')：16 字节 hex 字符串的 ASCII 编码 → base64
    const keyRaw = new util.TextEncoder().encodeInto(hex.substring(0, 16))
    return bytesToB64(keyRaw)
  }

  static bizError(message: string): NormalizedError {
    return new NormalizedError(ERR_HTTP_REQUEST_FAILED, message)
  }

  static logError(msg: string, e: BusinessErrorLike): void {
    hilog.error(DOMAIN, TAG, '%{public}s err=%{public}s', msg, JSON.stringify(e))
  }
}

export interface BusinessErrorLike {
  code?: number
  message?: string
}