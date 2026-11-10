/**
 * 通用 HTTP 请求工具 — 供在线音源 API（api/kw 等）使用
 * 封装 @kit.NetworkKit http：统一 15s 超时、UTF-8 文本响应、错误归一。
 * 所有失败路径（网络异常/超时/非 2xx）抛带 code 的 BusinessError，
 * 调用方必须 catch 并以 toast/状态呈现（不允许未处理 rejection）。
 */
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'HttpUtil'
const DOMAIN = 0x0001

/** 统一请求超时（spec 非功能要求：所有网络请求超时 15s） */
export const HTTP_TIMEOUT_MS = 15000

/** 归一错误码：请求失败（网络异常/超时/非 200） */
export const ERR_HTTP_REQUEST_FAILED = 2300025

export interface HttpResult {
  status: number
  body: string
}

/**
 * 归一错误类型（nominal class）：ArkTS 限制 throw 只能抛 Error 及其子类（arkts-limited-throw），
 * 接口形态的 BusinessError 不能直接 throw，统一改抛本类型（结构上兼容 BusinessError 消费方）。
 */
export class NormalizedError extends Error {
  public code: number

  constructor(code: number, message: string) {
    super(message)
    this.name = 'BusinessError'
    this.code = code
  }
}

function makeError(code: number, message: string): NormalizedError {
  return new NormalizedError(code, message)
}

/**
 * GET 请求，返回文本 body。
 * 非 2xx / 网络异常 / 超时 → 抛归一的 BusinessError（调用方 catch）。
 */
export async function httpGetText(url: string, headers?: Record<string, string>): Promise<HttpResult> {
  const httpRequest = http.createHttp()
  try {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      readTimeout: HTTP_TIMEOUT_MS,
      connectTimeout: HTTP_TIMEOUT_MS,
      expectDataType: http.HttpDataType.STRING
    }
    if (headers != undefined) {
      options.header = headers
    }
    const resp = await httpRequest.request(url, options)
    if (resp.responseCode < 200 || resp.responseCode >= 300) {
      hilog.error(DOMAIN, TAG, 'GET failed: %{public}s code=%{public}d', url, resp.responseCode)
      throw makeError(ERR_HTTP_REQUEST_FAILED, `HTTP ${resp.responseCode}`)
    }
    const result: HttpResult = { status: resp.responseCode, body: resp.result as string }
    return result
  } catch (e) {
    const err = e as BusinessError
    hilog.error(DOMAIN, TAG, 'GET error: %{public}s err=%{public}s', url, JSON.stringify(err))
    // 归一：保证抛出的永远是带数字 code 的 BusinessError
    if (err.code == undefined || typeof err.code != 'number' || err.code <= 0) {
      throw makeError(ERR_HTTP_REQUEST_FAILED, `network error: ${JSON.stringify(err)}`)
    }
    throw makeError(err.code, err.message != undefined ? err.message : 'request failed')
  } finally {
    try {
      httpRequest.destroy()
    } catch (ignored) {
      // ignore
    }
  }
}

/**
 * POST JSON 请求（application/json），返回文本 body。
 * 用于 tx 音源 musics.fcg（zzc 签名后 JSON 体直发）。
 * 非 2xx / 网络异常 / 超时 → 抛归一的 BusinessError（调用方 catch）。
 */
export async function httpPostJson(url: string, jsonBody: string,
  headers?: Record<string, string>): Promise<HttpResult> {
  const httpRequest = http.createHttp()
  try {
    const header: Record<string, string> = {
      'Content-Type': 'application/json'
    }
    if (headers != undefined) {
      const hKeys = Object.keys(headers)
      for (let i = 0; i < hKeys.length; i++) {
        header[hKeys[i]] = headers[hKeys[i]]
      }
    }
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: header,
      extraData: jsonBody,
      readTimeout: HTTP_TIMEOUT_MS,
      connectTimeout: HTTP_TIMEOUT_MS,
      expectDataType: http.HttpDataType.STRING
    }
    const resp = await httpRequest.request(url, options)
    if (resp.responseCode < 200 || resp.responseCode >= 300) {
      hilog.error(DOMAIN, TAG, 'POST JSON failed: %{public}s code=%{public}d', url, resp.responseCode)
      throw makeError(ERR_HTTP_REQUEST_FAILED, `HTTP ${resp.responseCode}`)
    }
    const result: HttpResult = { status: resp.responseCode, body: resp.result as string }
    return result
  } catch (e) {
    const err = e as BusinessError
    hilog.error(DOMAIN, TAG, 'POST JSON error: %{public}s err=%{public}s', url, JSON.stringify(err))
    if (err.code == undefined || typeof err.code != 'number' || err.code <= 0) {
      throw makeError(ERR_HTTP_REQUEST_FAILED, `network error: ${JSON.stringify(err)}`)
    }
    throw makeError(err.code, err.message != undefined ? err.message : 'request failed')
  } finally {
    try {
      httpRequest.destroy()
    } catch (ignored) {
      // ignore
    }
  }
}

/**
 * POST 表单请求（application/x-www-form-urlencoded），返回文本 body。
 * 用于 wy 音源 eapi/weapi（params/encSecKey 表单）。
 * 非 2xx / 网络异常 / 超时 → 抛归一的 BusinessError（调用方 catch）。
 */
export async function httpPostForm(url: string, form: Record<string, string>,
  headers?: Record<string, string>): Promise<HttpResult> {
  const httpRequest = http.createHttp()
  try {
    const parts: string[] = []
    const keys = Object.keys(form)
    for (let i = 0; i < keys.length; i++) {
      parts.push(`${encodeURIComponent(keys[i])}=${encodeURIComponent(form[keys[i]])}`)
    }
    const header: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded'
    }
    if (headers != undefined) {
      const hKeys = Object.keys(headers)
      for (let i = 0; i < hKeys.length; i++) {
        header[hKeys[i]] = headers[hKeys[i]]
      }
    }
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: header,
      extraData: parts.join('&'),
      readTimeout: HTTP_TIMEOUT_MS,
      connectTimeout: HTTP_TIMEOUT_MS,
      expectDataType: http.HttpDataType.STRING
    }
    const resp = await httpRequest.request(url, options)
    if (resp.responseCode < 200 || resp.responseCode >= 300) {
      hilog.error(DOMAIN, TAG, 'POST failed: %{public}s code=%{public}d', url, resp.responseCode)
      throw makeError(ERR_HTTP_REQUEST_FAILED, `HTTP ${resp.responseCode}`)
    }
    const result: HttpResult = { status: resp.responseCode, body: resp.result as string }
    return result
  } catch (e) {
    const err = e as BusinessError
    hilog.error(DOMAIN, TAG, 'POST error: %{public}s err=%{public}s', url, JSON.stringify(err))
    if (err.code == undefined || typeof err.code != 'number' || err.code <= 0) {
      throw makeError(ERR_HTTP_REQUEST_FAILED, `network error: ${JSON.stringify(err)}`)
    }
    throw makeError(err.code, err.message != undefined ? err.message : 'request failed')
  } finally {
    try {
      httpRequest.destroy()
    } catch (ignored) {
      // ignore
    }
  }
}