/**
 * PC 同步认证 — 对齐上游 `src/plugins/sync/client/auth.ts`
 * 流程：GET /hello（版本校验）→ GET /id（服务器 id）→ 认证：
 *  - codeAuth（首次，连接码）：key=md5(authCode)[0:16]；生成 RSA 对；msg=AES(`lx-music auth::\n{pub}\n{device}\nlx_music_mobile`)；
 *    GET /ah（header m）→ 响应 RSA(客户端私钥) 解密 → KeyInfo{key, clientId, serverName}
 *  - keyAuth（复连，KeyInfo）：msg=AES(`lx-music auth::{device}`)；GET /ah（header i/m）→ 响应 AES 解密须等于 helloMsg
 * httpProtocol：http/https；hostPath 形如 192.168.1.5:23332
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { httpGetText } from '../utils/HttpUtil'
import { md5Hex } from '../utils/CryptoUtil'
import { SyncCrypto, SyncRsaKeyPair, BusinessErrorLike } from './SyncCrypto'
import { SYNC_CODE, SYNC_DEVICE_NAME, SYNC_CLIENT_TAG, SyncKeyInfo } from './SyncConstants'

const TAG = 'SyncAuth'
const DOMAIN = 0x0001

export interface SyncUrlInfo {
  href: string
  httpProtocol: string
  wsProtocol: string
  hostPath: string
}

/** 解析服务器地址（对齐上游 parseUrl：去尾斜杠；https 前缀则 WS 用 wss） */
export function parseSyncUrl(href: string): SyncUrlInfo {
  let h = href.trim()
  if (h.endsWith('/')) {
    h = h.replace(/\/+$/, '')
  }
  const httpProtocol = /^https:/.test(h) ? 'https:' : 'http:'
  const info: SyncUrlInfo = {
    href: h,
    httpProtocol: httpProtocol,
    wsProtocol: httpProtocol == 'https:' ? 'wss:' : 'ws:',
    hostPath: h.replace(httpProtocol + '//', '')
  }
  return info
}

async function hello(urlInfo: SyncUrlInfo): Promise<boolean> {
  try {
    const resp = await httpGetText(`${urlInfo.httpProtocol}//${urlInfo.hostPath}/hello`)
    const text = resp.body
    if (text == SYNC_CODE.helloMsg) {
      return true
    }
    if (text.startsWith('Hello~::^-^::')) {
      const verRxp = /v(\d+)/
      const result = verRxp.exec(text)
      if (result != null && result.length > 1) {
        const servVer = parseInt(result[1])
        const local = verRxp.exec(SYNC_CODE.helloMsg)
        const localVer = local != null ? parseInt(local[1]) : 4
        if (servVer > localVer) {
          throw SyncCrypto.bizError(SYNC_CODE.highServiceVersion)
        } else if (servVer < localVer) {
          throw SyncCrypto.bizError(SYNC_CODE.lowServiceVersion)
        }
      }
    }
    return false
  } catch (e) {
    SyncCrypto.logError('hello', e as BusinessErrorLike)
    return false
  }
}

async function getServerId(urlInfo: SyncUrlInfo): Promise<string> {
  const resp = await httpGetText(`${urlInfo.httpProtocol}//${urlInfo.hostPath}/id`)
  if (!resp.body.startsWith(SYNC_CODE.idPrefix)) {
    return ''
  }
  return resp.body.replace(SYNC_CODE.idPrefix, '')
}

async function codeAuth(urlInfo: SyncUrlInfo, authCode: string): Promise<SyncKeyInfo> {
  const key = await SyncCrypto.deriveKeyFromAuthCode(authCode)
  const pair: SyncRsaKeyPair = await SyncCrypto.generateRsaKey()
  const msg = await SyncCrypto.aesEncrypt(
    `${SYNC_CODE.authMsg}\n${pair.publicKey}\n${SYNC_DEVICE_NAME}\n${SYNC_CLIENT_TAG}`, key)
  const headers: Record<string, string> = { 'm': msg }
  const resp = await httpGetText(`${urlInfo.httpProtocol}//${urlInfo.hostPath}/ah`, headers)
  if (resp.body == SYNC_CODE.msgBlockedIp) {
    throw SyncCrypto.bizError(SYNC_CODE.msgBlockedIp)
  }
  if (resp.body == SYNC_CODE.msgAuthFailed || resp.status != 200) {
    throw SyncCrypto.bizError(SYNC_CODE.authFailed)
  }
  let plain: string
  try {
    plain = await SyncCrypto.rsaDecrypt(resp.body, pair.privateKey)
  } catch (e) {
    SyncCrypto.logError('codeAuth decryptMsg', e as BusinessErrorLike)
    throw SyncCrypto.bizError(SYNC_CODE.authFailed)
  }
  if (plain.length == 0) {
    throw SyncCrypto.bizError(SYNC_CODE.authFailed)
  }
  const info = JSON.parse(plain) as SyncKeyInfo
  return info
}

async function keyAuth(urlInfo: SyncUrlInfo, keyInfo: SyncKeyInfo): Promise<void> {
  const msg = await SyncCrypto.aesEncrypt(`${SYNC_CODE.authMsg}${SYNC_DEVICE_NAME}`, keyInfo.key)
  const headers: Record<string, string> = {
    'i': keyInfo.clientId,
    'm': msg
  }
  const resp = await httpGetText(`${urlInfo.httpProtocol}//${urlInfo.hostPath}/ah`, headers)
  if (resp.status != 200) {
    throw SyncCrypto.bizError(SYNC_CODE.authFailed)
  }
  let plain: string
  try {
    plain = await SyncCrypto.aesDecrypt(resp.body, keyInfo.key)
  } catch (e) {
    SyncCrypto.logError('keyAuth decryptMsg', e as BusinessErrorLike)
    throw SyncCrypto.bizError(SYNC_CODE.authFailed)
  }
  if (plain != SYNC_CODE.helloMsg) {
    throw SyncCrypto.bizError(SYNC_CODE.authFailed)
  }
}

export interface AuthResult {
  serverId: string
  keyInfo: SyncKeyInfo
}

/**
 * 认证入口（对齐上游 auth 导出）：hello → serverId → codeAuth / keyAuth。
 * authCode 非空走 codeAuth；否则使用已保存 keyInfo（getSavedKeyInfo 由 SyncManager 提供）。
 */
export async function auth(urlInfo: SyncUrlInfo, authCode: string | undefined,
  getSavedKeyInfo: () => SyncKeyInfo | undefined): Promise<AuthResult> {
  if (!await hello(urlInfo)) {
    throw SyncCrypto.bizError(SYNC_CODE.connectServiceFailed)
  }
  const serverId = await getServerId(urlInfo)
  if (serverId.length == 0) {
    throw SyncCrypto.bizError(SYNC_CODE.getServiceIdFailed)
  }
  if (authCode != undefined && authCode.length > 0) {
    const keyInfo = await codeAuth(urlInfo, authCode.trim())
    const out: AuthResult = { serverId: serverId, keyInfo: keyInfo }
    return out
  }
  const saved = getSavedKeyInfo()
  if (saved == undefined) {
    throw SyncCrypto.bizError(SYNC_CODE.missingAuthCode)
  }
  await keyAuth(urlInfo, saved)
  const out: AuthResult = { serverId: serverId, keyInfo: saved }
  return out
}

export function logAuthError(scope: string, e: BusinessErrorLike): void {
  hilog.error(DOMAIN, TAG, '%{public}s: %{public}s', scope, JSON.stringify(e))
}