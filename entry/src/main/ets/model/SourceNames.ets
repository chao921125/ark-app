/**
 * 音源名称映射 — 纯函数模块
 *
 * 用于在搜索结果/歌单列表上标注歌曲来自哪个音源（对齐上游 lx-music 的「来源」展示）。
 */

/** 内置音源与自定义脚本的中文名 */
const SOURCE_NAMES: Record<string, string> = {
  'kw': '酷我',
  'wy': '网易云',
  'kg': '酷狗',
  'tx': 'QQ音乐',
  'mg': '咪咕',
  'custom': '自定义脚本'
}

/**
 * 音源 id → 显示名称。
 * 未登记的 id 原样返回（自定义脚本的 id 形如「xx音源名」，直接展示更直观）。
 */
export function sourceName(id: string): string {
  if (id.length === 0) {
    return ''
  }
  const name: string | undefined = SOURCE_NAMES[id]
  return name != undefined ? name : id
}
