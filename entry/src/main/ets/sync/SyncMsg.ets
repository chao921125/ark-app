/**
 * PC 同步消息层 — 对齐上游 `src/plugins/sync/client/utils.ts`（encryptMsg/decryptMsg）
 * 与 message2call 库（github.com/lyswhut/message2call）的 wire 协议：
 *  - 传输消息：>1024 字符时 'cg_' 前缀 + gzip(utf8) 的 base64（HarmonyOS zlib 为文件级 API，经临时文件中转）；
 *    否则原文（上游 v1.8 已去除消息体 AES，注释保留）
 *  - RPC：REQUEST=[0, eventName, path[], args[], callbacks[]]；RESPONSE=[1, eventName, err|null, result?]；
 *    CALLBACK_REQUEST=[2, name, args[]]；CALLBACK_RESPONSE=[3, name, err|null, result?]
 */
import zlib from '@ohos.zlib'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { NormalizedError, ERR_HTTP_REQUEST_FAILED } from '../utils/HttpUtil'

const TAG = 'SyncMsg'
const DOMAIN = 0x0001

const GZIP_THRESHOLD = 1024
const GZIP_PREFIX = 'cg_'

export const CALL_REQUEST = 0
export const CALL_RESPONSE = 1
export const CALL_CALLBACK_REQUEST = 2
export const CALL_CALLBACK_RESPONSE = 3

interface RpcError {
  message: string
}

class SyncMsgImpl {
  private cacheDir: string = ''

  init(context: common.UIAbilityContext): void {
    this.cacheDir = context.cacheDir
  }

  // ---- gzip（临时文件中转，对齐上游 gzipString/unGzipString）----

  private async writeFileBytes(path: string, bytes: Uint8Array): Promise<void> {
    const f = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    try {
      fs.writeSync(f.fd, bytes.buffer as object as ArrayBuffer)
    } finally {
      fs.closeSync(f.fd)
    }
  }

  private async readFileBytes(path: string): Promise<Uint8Array> {
    const stat = fs.statSync(path)
    const f = fs.openSync(path, fs.OpenMode.READ_ONLY)
    try {
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(f.fd, buf)
      return new Uint8Array(buf)
    } finally {
      fs.closeSync(f.fd)
    }
  }

  private async gzFile(inPath: string, outPath: string): Promise<void> {
    await zlib.compressFile(inPath, outPath, {})
  }

  private async unGzFile(inPath: string, outPath: string): Promise<void> {
    await zlib.decompressFile(inPath, outPath, {})
  }

  async gzipString(text: string): Promise<string> {
    if (this.cacheDir.length == 0) {
      throw new NormalizedError(ERR_HTTP_REQUEST_FAILED, 'sync msg not init')
    }
    const id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`
    const inPath = `${this.cacheDir}/sync_gz_in_${id}`
    const outPath = `${this.cacheDir}/sync_gz_out_${id}`
    try {
      await this.writeFileBytes(inPath, new util.TextEncoder().encodeInto(text))
      await this.gzFile(inPath, outPath)
      const gzBytes = await this.readFileBytes(outPath)
      return new util.Base64Helper().encodeToStringSync(gzBytes)
    } finally {
      try {
        fs.unlinkSync(inPath)
      } catch (ignored) {
      }
      try {
        fs.unlinkSync(outPath)
      } catch (ignored) {
      }
    }
  }

  async unGzipString(b64: string): Promise<string> {
    if (this.cacheDir.length == 0) {
      throw new NormalizedError(ERR_HTTP_REQUEST_FAILED, 'sync msg not init')
    }
    const id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`
    const inPath = `${this.cacheDir}/sync_ungz_in_${id}`
    const outPath = `${this.cacheDir}/sync_ungz_out_${id}`
    try {
      await this.writeFileBytes(inPath, new util.Base64Helper().decodeSync(b64))
      await this.unGzFile(inPath, outPath)
      const bytes = await this.readFileBytes(outPath)
      return new util.TextDecoder('utf-8').decodeToString(bytes)
    } finally {
      try {
        fs.unlinkSync(inPath)
      } catch (ignored) {
      }
      try {
        fs.unlinkSync(outPath)
      } catch (ignored) {
      }
    }
  }

  // ---- 传输层编解码（对齐 encryptMsg/decryptMsg）----

  async encodeWire(msg: string): Promise<string> {
    return msg.length > GZIP_THRESHOLD ? GZIP_PREFIX + await this.gzipString(msg) : msg
  }

  async decodeWire(wire: string): Promise<string> {
    return wire.substring(0, GZIP_PREFIX.length) == GZIP_PREFIX
      ? this.unGzipString(wire.substring(GZIP_PREFIX.length)) : wire
  }

  // ---- message2call RPC ----

  /** 生成请求 eventName（对齐 message2call：`${path.join('.')}_${random}`） */
  makeEventName(path: string[]): string {
    return `${path.join('.')}_${Math.random().toString(36).slice(2)}`
  }

  /** 构建调用请求消息（返回可 JSON.stringify 的数组） */
  buildRequest(eventName: string, path: string[], args: Array<Object>): Array<Object> {
    const msg: Array<Object> = [CALL_REQUEST, eventName, path, args, []]
    return msg
  }

  /** 构建响应消息 */
  buildResponse(eventName: string, errMessage: string | null, result: Object | undefined): Array<Object | null> {
    if (errMessage != null) {
      const err: RpcError = { message: errMessage }
      const msg: Array<Object | null> = [CALL_RESPONSE, eventName, err]
      return msg
    }
    if (result == undefined) {
      const msg: Array<Object | null> = [CALL_RESPONSE, eventName, null]
      return msg
    }
    const msg: Array<Object | null> = [CALL_RESPONSE, eventName, null, result]
    return msg
  }

  /** 解析 wire → 数组消息；失败抛错（调用方关闭连接，对齐上游 parse msg error） */
  parseMessage(wire: string): Array<Object> {
    const parsed = JSON.parse(wire) as Array<Object>
    if (parsed.length < 2) {
      throw new NormalizedError(ERR_HTTP_REQUEST_FAILED, 'bad rpc message')
    }
    return parsed
  }

  logError(scope: string, e: Object): void {
    hilog.error(DOMAIN, TAG, '%{public}s err=%{public}s', scope, JSON.stringify(e))
  }
}

export const SyncMsg: SyncMsgImpl = new SyncMsgImpl()