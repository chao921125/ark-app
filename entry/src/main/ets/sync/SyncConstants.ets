/**
 * PC 同步常量 — 对齐上游 lx-music-mobile `src/plugins/sync/constants.ts`
 */

/** 认证/握手消息（协议版本 v4） */
export interface SyncCode {
  helloMsg: string
  /** 服务器 id 响应前缀（base64 变形前缀，直接字符串匹配） */
  idPrefix: string
  authMsg: string
  msgAuthFailed: string
  msgBlockedIp: string
  msgConnect: string
  authFailed: string
  missingAuthCode: string
  getServiceIdFailed: string
  connectServiceFailed: string
  connecting: string
  unknownServiceAddress: string
  lowServiceVersion: string
  highServiceVersion: string
}

export const SYNC_CODE: SyncCode = {
  helloMsg: 'Hello~::^-^::~v4~',
  idPrefix: 'OjppZDo6',
  authMsg: 'lx-music auth::',
  msgAuthFailed: 'Auth failed',
  msgBlockedIp: 'Blocked IP',
  msgConnect: 'lx-music connect',
  authFailed: 'Auth failed',
  missingAuthCode: 'Missing auth code',
  getServiceIdFailed: 'Get service id failed',
  connectServiceFailed: 'Connect service failed',
  connecting: 'Connecting...',
  unknownServiceAddress: 'Unknown service address',
  lowServiceVersion: 'Sync server version too low, please upgrade server to latest',
  highServiceVersion: 'Sync server version too high, please upgrade app to latest'
}

/** WS 关闭码（对齐上游 SYNC_CLOSE_CODE） */
export interface SyncCloseCode {
  normal: number
  failed: number
}

export const SYNC_CLOSE_CODE: SyncCloseCode = {
  normal: 1000,
  failed: 4100
}

/** 同步模式（对齐上游 LX.Sync.List.SyncMode） */
export type SyncMode = 'merge_local_remote' | 'merge_remote_local'
  | 'overwrite_local_remote' | 'overwrite_remote_local'
  | 'overwrite_local_remote_full' | 'overwrite_remote_local_full' | 'cancel'

/** 客户端支持的特性版本（对齐上游 featureVersion；dislike 本工程未实现固定不支持） */
export const FEATURE_VERSION_LIST = 1

/** 同步状态（对齐上游 LX.Sync.Status） */
export interface SyncStatus {
  status: boolean
  message: string
  /** 服务器地址（连接成功后填充） */
  address: string
  serverName: string
}

/** 连接密钥信息（对齐上游 LX.Sync.KeyInfo，持久化后可免连接码复连） */
export interface SyncKeyInfo {
  key: string
  clientId: string
  serverName: string
}

export const SYNC_DEVICE_NAME = 'HarmonyOS Device'
export const SYNC_CLIENT_TAG = 'lx_music_mobile'