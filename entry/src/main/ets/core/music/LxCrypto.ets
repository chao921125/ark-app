/**
 * LxCrypto — 洛雪音源加密工具（最小集）
 * 仅提供 SourceEngine 所需的 utf8Bytes 函数。
 */

/** 字符串 -> UTF-8 字节 */
export function utf8Bytes(str: string): number[] {
  const out: number[] = [];
  for (let i = 0; i < str.length; i++) {
    let code: number = str.charCodeAt(i);
    if (code >= 0xD800 && code <= 0xDBFF && i + 1 < str.length) {
      const next: number = str.charCodeAt(i + 1);
      if (next >= 0xDC00 && next <= 0xDFFF) {
        code = ((code - 0xD800) << 10) + (next - 0xDC00) + 0x10000;
        i++;
      }
    }
    if (code < 0x80) {
      out.push(code);
    } else if (code < 0x800) {
      out.push((code >> 6) | 0xC0, (code & 0x3F) | 0x80);
    } else if (code < 0x10000) {
      out.push((code >> 12) | 0xE0, ((code >> 6) & 0x3F) | 0x80, (code & 0x3F) | 0x80);
    } else {
      out.push(
        (code >> 18) | 0xF0,
        ((code >> 12) & 0x3F) | 0x80,
        ((code >> 6) & 0x3F) | 0x80,
        (code & 0x3F) | 0x80,
      );
    }
  }
  return out;
}
