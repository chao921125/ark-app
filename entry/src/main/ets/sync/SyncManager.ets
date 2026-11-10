/**
 * PC 同步总控 — 对齐上游 `src/plugins/sync/client/client.ts` + `src/core/sync.ts`
 * 流程：connectServer(host, authCode?) → HTTP 认证（SyncAuth）→ WS 认证
 *   （ws://host/socket?i={clientId}&t=AES('lx-music connect', key)）→ RPC 同步（message2call 协议）：
 *   服务端依次调用 getEnabledFeatures → list_sync_get_sync_mode（客户端弹窗选择模式）→
 *   list_sync_get_md5 / get_list_data / set_list_data / onListSyncAction（增量）→
 *   list_sync_finished → finished（同步完成）
 * 心跳：服务端每 30s 发 'ping'，31s 未收到则断开重连（指数退避 2s→30s）。
 * V1 限制：本地改动不实时上行（isRemote 回环阻断未实现，见收敛报告），下次连接时合并同步。
 */
import { webSocket } from '@kit.NetworkKit'
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { md5Hex } from '../utils/CryptoUtil'
import { NormalizedError, ERR_HTTP_REQUEST_FAILED } from '../utils/HttpUtil'
import { auth, parseSyncUrl, SyncUrlInfo } from './SyncAuth'
import { SyncMsg, CALL_REQUEST, CALL_RESPONSE, CALL_CALLBACK_REQUEST, CALL_CALLBACK_RESPONSE } from './SyncMsg'
import { SyncListDataOps, SyncListData, SyncListAction } from './SyncListData'
import { SYNC_CODE, SYNC_CLOSE_CODE, FEATURE_VERSION_LIST, SyncKeyInfo, SyncStatus } from './SyncConstants'
import { SyncCrypto } from './SyncCrypto'
import { PreferencesUtil } from '../persistence/PreferencesUtil'

const TAG = 'SyncManager'
const DOMAIN = 0x0001

const KEY_SYNC_HOST = 'sync_host_v1'
const KEY_SYNC_KEYINFO = 'sync_keyinfo_v1'

/** 同步模式请求（UI 弹层） */
export interface SyncModeRequest {
  serverName: string
  rev: number
}

type CallbackHandler = (errMessage: string | null, result: Object | undefined) => void

interface ModePromise {
  resolve: (mode: string) => void
  reject: () => void
}

interface SupportedFeatures {
  list?: number
}

interface SyncFeatureItem {
  skipSnapshot: boolean
}

interface SyncEnabledFeatures {
  list: SyncFeatureItem
}

class SyncManagerImpl {
  private ws?: webSocket.WebSocket
  private urlInfo?: SyncUrlInfo
  private keyInfo?: SyncKeyInfo
  private serverId: string = ''
  private manualClosed: boolean = false
  private failedNum: number = 0
  private pingTimer: number = -1
  private reconnectTimer: number = -1
  private pendingCallbacks: Map<string, CallbackHandler> = new Map()
  private modePromise?: ModePromise
  private status: SyncStatus = { status: false, message: '', address: '', serverName: '' }
  /** list 模块同步完成（list_sync_finished） */
  private listReady: boolean = false
  /** 整体同步完成（finished），状态栏显示已连接 */
  private isReady: boolean = false

  init(context: common.UIAbilityContext): void {
    SyncMsg.init(context)
  }

  getStatus(): SyncStatus {
    return this.status
  }

  private sendStatus(status: boolean, message: string, serverName: string): void {
    this.status = { status: status, message: message, address: this.urlInfo?.href ?? '', serverName: serverName }
    AppStorage.setOrCreate<string>('syncStatusJson', JSON.stringify(this.status))
    const rev = AppStorage.get<number>('syncStatusRev') ?? 0
    AppStorage.setOrCreate<number>('syncStatusRev', rev + 1)
  }

  // ---- 持久化（对齐上游 getSyncAuthKey/setSyncAuthKey/getSyncHost）----

  async getSavedHost(): Promise<string> {
    try {
      return await PreferencesUtil.getString(KEY_SYNC_HOST)
    } catch (ignored) {
      return ''
    }
  }

  private async saveKeyInfo(serverId: string, keyInfo: SyncKeyInfo): Promise<void> {
    this.serverId = serverId
    this.keyInfo = keyInfo
    try {
      await PreferencesUtil.setString(KEY_SYNC_KEYINFO, JSON.stringify(keyInfo))
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'saveKeyInfo failed: %{public}s', JSON.stringify(e))
    }
  }

  private loadKeyInfo(): SyncKeyInfo | undefined {
    return this.keyInfo
  }

  private async loadPersistedKeyInfo(): Promise<void> {
    try {
      const json = await PreferencesUtil.getString(KEY_SYNC_KEYINFO)
      if (json.length > 0) {
        this.keyInfo = JSON.parse(json) as SyncKeyInfo
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'loadPersistedKeyInfo failed: %{public}s', JSON.stringify(e))
    }
  }

  // ---- 连接 ----

  async connectServer(host: string, authCode?: string): Promise<void> {
    if (this.ws != undefined) {
      await this.disconnectServer()
    }
    await this.loadPersistedKeyInfo()
    const trimmed = host.trim()
    if (trimmed.length == 0) {
      throw new NormalizedError(ERR_HTTP_REQUEST_FAILED, SYNC_CODE.unknownServiceAddress)
    }
    const urlInfo = parseSyncUrl(trimmed)
    this.urlInfo = urlInfo
    this.manualClosed = false
    this.failedNum = 0
    this.sendStatus(false, SYNC_CODE.connecting, '')
    try {
      await PreferencesUtil.setString(KEY_SYNC_HOST, urlInfo.href)
    } catch (ignored) {
    }
    const authResult = await auth(urlInfo, authCode, () => this.loadKeyInfo())
    this.serverId = authResult.serverId
    this.keyInfo = authResult.keyInfo
    await this.saveKeyInfo(authResult.serverId, authResult.keyInfo)
    this.sendStatus(false, SYNC_CODE.connecting, this.keyInfo.serverName)
    this.connectSocket()
  }

  private connectSocket(): void {
    const urlInfo = this.urlInfo
    const keyInfo = this.keyInfo
    if (urlInfo == undefined || keyInfo == undefined) {
      return
    }
    void (async () => {
      try {
        const t = await SyncCrypto.aesEncrypt(SYNC_CODE.msgConnect, keyInfo.key)
        const ws = webSocket.createWebSocket()
        this.ws = ws
        this.bindSocketEvents(ws)
        ws.connect(`${urlInfo.wsProtocol}//${urlInfo.hostPath}/socket?i=${encodeURIComponent(keyInfo.clientId)}` +
          `&t=${encodeURIComponent(t)}`, { header: {} }, (err: BusinessError) => {
          if (err && err.code != 0) {
            hilog.error(DOMAIN, TAG, 'ws connect failed: %{public}s', JSON.stringify(err))
            this.onSocketClosed(-1)
          }
        })
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'connectSocket error: %{public}s', JSON.stringify(e))
        this.onSocketClosed(-1)
      }
    })()
  }

  async disconnectServer(): Promise<void> {
    this.manualClosed = true
    this.clearTimers()
    const ws = this.ws
    this.ws = undefined
    if (ws != undefined) {
      try {
        await ws.close({ code: SYNC_CLOSE_CODE.normal, reason: 'bye' })
      } catch (ignored) {
      }
    }
    this.sendStatus(false, '', '')
  }

  // ---- 心跳与重连（对齐上游 heartbeatTools）----

  private clearTimers(): void {
    if (this.pingTimer >= 0) {
      clearTimeout(this.pingTimer)
      this.pingTimer = -1
    }
    if (this.reconnectTimer >= 0) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = -1
    }
  }

  private resetHeartbeat(): void {
    if (this.pingTimer >= 0) {
      clearTimeout(this.pingTimer)
    }
    this.pingTimer = setTimeout(() => {
      this.pingTimer = -1
      const ws = this.ws
      if (ws != undefined) {
        try {
          ws.close({ code: SYNC_CLOSE_CODE.failed, reason: 'ping timeout' })
        } catch (ignored) {
        }
      }
    }, 31000)
  }

  private onSocketClosed(code: number): void {
    this.clearTimers()
    this.listReady = false
    this.isReady = false
    const wasWs = this.ws != undefined
    this.ws = undefined
    if (this.manualClosed) {
      return
    }
    // 主动断开码（normal/failed）不重连，其余重连（对齐上游）
    if (wasWs && (code == SYNC_CLOSE_CODE.normal || code == SYNC_CLOSE_CODE.failed)) {
      this.sendStatus(false, code == SYNC_CLOSE_CODE.failed ? 'failed' : '', this.keyInfo?.serverName ?? '')
      return
    }
    this.scheduleReconnect()
  }

  private scheduleReconnect(): void {
    this.failedNum++
    const waitTime = Math.min(2000 + Math.floor(this.failedNum / 2) * 3000, 30000)
    this.sendStatus(false, `Try reconnect... (${this.failedNum})`, this.keyInfo?.serverName ?? '')
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = -1
      this.connectSocket()
    }, waitTime)
  }

  private bindSocketEvents(ws: webSocket.WebSocket): void {
    ws.on('open', () => {
      this.resetHeartbeat()
    })
    ws.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (err && err.code != 0) {
        return
      }
      if (typeof value == 'string') {
        this.handleWire(value)
      }
    })
    ws.on('close', (err: BusinessError, value: webSocket.CloseResult) => {
      this.onSocketClosed(value != undefined ? value.code : -1)
    })
    ws.on('error', (err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'ws error: %{public}s', JSON.stringify(err))
    })
  }

  // ---- 传输与消息分发 ----

  private async sendRaw(data: string): Promise<boolean> {
    const ws = this.ws
    if (ws == undefined) {
      return false
    }
    try {
      await ws.send(data)
      return true
    } catch (e) {
      SyncMsg.logError('ws send', e as BusinessErrorLike)
      return false
    }
  }

  private async callRemote(path: string[], args: Array<Object>, timeoutMs: number): Promise<Object | undefined> {
    if (this.ws == undefined) {
      throw new NormalizedError(ERR_HTTP_REQUEST_FAILED, 'disconnected')
    }
    const eventName = SyncMsg.makeEventName(path)
    const msg = SyncMsg.buildRequest(eventName, path, args)
    const wire = await SyncMsg.encodeWire(JSON.stringify(msg))
    const sent = await this.sendRaw(wire)
    if (!sent) {
      throw new NormalizedError(ERR_HTTP_REQUEST_FAILED, 'disconnected')
    }
    return new Promise<Object | undefined>((resolve, reject) => {
      let timer = -1
      this.pendingCallbacks.set(eventName, (errMessage, result) => {
        if (timer >= 0) {
          clearTimeout(timer)
        }
        this.pendingCallbacks.delete(eventName)
        if (errMessage == null) {
          resolve(result)
        } else {
          reject(new NormalizedError(ERR_HTTP_REQUEST_FAILED, errMessage))
        }
      })
      timer = setTimeout(() => {
        if (this.pendingCallbacks.has(eventName)) {
          this.pendingCallbacks.delete(eventName)
          reject(new NormalizedError(ERR_HTTP_REQUEST_FAILED, 'call remote timeout'))
        }
      }, timeoutMs)
    })
  }

  private handleWire(data: string): void {
    if (data == 'ping') {
      this.resetHeartbeat()
      return
    }
    void (async () => {
      let wire: string
      try {
        wire = await SyncMsg.decodeWire(data)
      } catch (e) {
        SyncMsg.logError('decode msg', e as BusinessErrorLike)
        this.closeFailed()
        return
      }
      let msg: Array<Object>
      try {
        msg = SyncMsg.parseMessage(wire)
      } catch (e) {
        SyncMsg.logError('parse msg', e as BusinessErrorLike)
        this.closeFailed()
        return
      }
      const type = msg[0] as number
      if (type == CALL_RESPONSE || type == CALL_CALLBACK_RESPONSE) {
        const eventName = `${msg[1]}`
        const errObj = msg[2] as BusinessErrorLike | null
        const handler = this.pendingCallbacks.get(eventName)
        if (handler == undefined) {
          return
        }
        if (errObj != null && errObj != undefined) {
          handler(`${errObj.message ?? 'unknown error'}`, undefined)
        } else {
          handler(null, msg.length > 3 ? msg[3] as Object : undefined)
        }
        return
      }
      if (type == CALL_REQUEST) {
        await this.handleRemoteRequest(msg)
        return
      }
      if (type == CALL_CALLBACK_REQUEST) {
        // 本工程 handler 未使用回调参数，忽略（对齐 message2call：无注册即无响应）
        return
      }
    })()
  }

  private closeFailed(): void {
    const ws = this.ws
    if (ws != undefined) {
      try {
        ws.close({ code: SYNC_CLOSE_CODE.failed, reason: 'bad msg' })
      } catch (ignored) {
      }
    }
  }

  private async handleRemoteRequest(msg: Array<Object>): Promise<void> {
    const eventName = `${msg[1]}`
    const pathArr = msg[2] as Array<string>
    const args = msg[3] as Array<Object>
    const name = pathArr != undefined && pathArr.length > 0 ? pathArr[pathArr.length - 1] : ''
    try {
      const result = await this.dispatchCall(name, args)
      const resp = SyncMsg.buildResponse(eventName, null, result)
      const ok = await this.sendRaw(await SyncMsg.encodeWire(JSON.stringify(resp)))
      if (!ok) {
        this.closeFailed()
      }
    } catch (e) {
      const err = e as BusinessErrorLike
      const resp = SyncMsg.buildResponse(eventName, err.message ?? 'call error', undefined)
      const ok = await this.sendRaw(await SyncMsg.encodeWire(JSON.stringify(resp)))
      if (!ok) {
        this.closeFailed()
      }
    }
  }

  /** 客户端暴露给服务端的动作（对齐上游 callObj：handler + modules） */
  private async dispatchCall(name: string, args: Array<Object>): Promise<Object | undefined> {
    switch (name) {
      case 'getEnabledFeatures': {
        // args: [socket, serverType, supportedFeatures]；仅声明 list 特性（dislike 未实现）
        const supported = args.length > 2 ? args[2] as SupportedFeatures : undefined
        if (supported != undefined && supported.list != undefined &&
          (supported.list as number) == FEATURE_VERSION_LIST) {
          const features: SyncEnabledFeatures = { list: { skipSnapshot: false } }
          return features
        }
        const empty: ESObject = {}
        return empty
      }
      case 'list_sync_get_md5': {
        const data = SyncListDataOps.getLocalListData()
        return await md5Hex(JSON.stringify(data))
      }
      case 'list_sync_get_sync_mode': {
        return await this.requestSyncMode()
      }
      case 'list_sync_get_list_data': {
        return SyncListDataOps.getLocalListData()
      }
      case 'list_sync_set_list_data': {
        const data = args.length > 1 ? args[1] as SyncListData : undefined
        if (data == undefined) {
          throw new NormalizedError(ERR_HTTP_REQUEST_FAILED, 'bad list data')
        }
        await SyncListDataOps.setLocalListData(data)
        return undefined
      }
      case 'onListSyncAction': {
        const action = args.length > 1 ? args[1] as SyncListAction : undefined
        if (action == undefined) {
          return undefined
        }
        await SyncListDataOps.handleRemoteListAction(action)
        return undefined
      }
      case 'list_sync_finished': {
        this.listReady = true
        return undefined
      }
      case 'finished': {
        this.isReady = true
        this.clearTimers()
        this.resetHeartbeat()
        this.sendStatus(true, '', this.keyInfo?.serverName ?? '')
        promptAction.showToast({ message: '同步成功', duration: 2000 })
        return undefined
      }
      default:
        throw new NormalizedError(ERR_HTTP_REQUEST_FAILED, `${name} is not defined`)
    }
  }

  /** 模式选择（对齐上游 selectSyncMode：弹窗等待用户选择） */
  private requestSyncMode(): Promise<string> {
    if (this.modePromise != undefined) {
      // 上一次请求未被处理（弹层被下拉关闭等）→ 废弃后新建
      const old = this.modePromise
      this.modePromise = undefined
      old.reject()
    }
    return new Promise<string>((resolve, reject) => {
      this.modePromise = { resolve: resolve, reject: reject }
      AppStorage.setOrCreate<string>('syncModeServerName', this.keyInfo?.serverName ?? '')
      const rev = AppStorage.get<number>('syncModeRequestRev') ?? 0
      AppStorage.setOrCreate<number>('syncModeRequestRev', rev + 1)
    })
  }

  /** UI 弹层调用：用户选择模式（cancel → 断开） */
  resolveSyncMode(mode: string): void {
    const p = this.modePromise
    this.modePromise = undefined
    if (p == undefined) {
      return
    }
    p.resolve(mode)
  }

  /** UI 弹层关闭/取消 */
  cancelSyncMode(): void {
    const p = this.modePromise
    this.modePromise = undefined
    if (p != undefined) {
      p.reject()
      void this.disconnectServer()
    }
  }

  /** 本地列表变化后由 UI 触发（V1：不做自动上行，仅状态提示，见报告） */
  onLocalListChanged(): void {
    if (this.isReady) {
      this.sendStatus(true, '本地有改动，重新连接后同步', this.keyInfo?.serverName ?? '')
    }
  }
}

export interface BusinessErrorLike {
  code?: number
  message?: string
}

export const SyncManager: SyncManagerImpl = new SyncManagerImpl()