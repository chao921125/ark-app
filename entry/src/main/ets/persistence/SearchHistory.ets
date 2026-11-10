/**
 * 搜索历史持久化 — 对齐上游 `search.isShowHistorySearch`
 *
 * 上游把搜索历史放在本地存储里，本项目沿用 Preferences 存一份 JSON 数组。
 */
import { PreferencesUtil } from './PreferencesUtil'

const KEY_HISTORY = 'search_history_v1'
/** 历史记录条数上限 */
const MAX_HISTORY: number = 10

class SearchHistoryImpl {
  /** 读取搜索历史（最近的在最前） */
  async get(): Promise<string[]> {
    try {
      const json = await PreferencesUtil.getString(KEY_HISTORY)
      if (json.length === 0) {
        return []
      }
      const list = JSON.parse(json) as string[]
      return Array.isArray(list) ? list : []
    } catch (e) {
      return []
    }
  }

  /** 记录一条搜索关键词（重复的移到最前） */
  async add(keyword: string): Promise<void> {
    const trimmed = keyword.trim()
    if (trimmed.length === 0) {
      return
    }
    const list = await this.get()
    const next: string[] = [trimmed]
    for (let i = 0; i < list.length; i++) {
      if (list[i] != trimmed && next.length < MAX_HISTORY) {
        next.push(list[i])
      }
    }
    try {
      await PreferencesUtil.setString(KEY_HISTORY, JSON.stringify(next))
    } catch (e) {
      // 持久化失败不影响搜索本身
    }
  }

  /** 清空搜索历史 */
  async clear(): Promise<void> {
    try {
      await PreferencesUtil.remove(KEY_HISTORY)
    } catch (e) {
      // ignore
    }
  }
}

export const SearchHistory: SearchHistoryImpl = new SearchHistoryImpl()
