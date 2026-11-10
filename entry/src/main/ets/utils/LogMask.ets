/**
 * 日志脱敏工具 — 纯函数模块（无平台依赖，可被验证台直接覆盖）
 *
 * 背景：音源脚本常在请求里带 key/token 等凭据，而请求日志既写进 hilog
 * （系统日志，任何能读日志的地方都能拿到），又展示在用户可见的「音源日志」面板里。
 * 直接写原文等于凭据泄漏，因此统一在这里做脱敏。
 */

/** 敏感参数名（查询串与 JSON 字段都覆盖） */
const SENSITIVE_KEY_PATTERN: string =
  'key|token|secret|sign|auth|session|password|pwd|access_key|secret_key|appkey|app_secret|' +
  'checkUpdate|checksum|signature|sign_key|private_key'

/** 把 URL 查询串里的敏感参数值替换为 *** */
export function maskSensitiveUrl(url: string): string {
  if (url.length === 0) {
    return url
  }
  try {
    return url.replace(new RegExp(`([?&](?:${SENSITIVE_KEY_PATTERN})=)[^&]*`, 'gi'), '$1***')
  } catch (e) {
    // 正则异常时宁可原样返回，也不要因脱敏失败而丢日志
    return url
  }
}

/** 把文本里 JSON 形态的敏感字段值替换为 ***（如 {"key":"abc"}） */
export function maskSensitiveText(text: string): string {
  if (text.length === 0) {
    return text
  }
  try {
    return text.replace(new RegExp(`("(?:${SENSITIVE_KEY_PATTERN})"\\s*:\\s*")([^"]*)(")`, 'gi'), '$1***$3')
  } catch (e) {
    return text
  }
}
