/**
 * Preferences 持久化封装 — 对齐上游 `src/plugins/storage.ts`（AsyncStorage → Preferences）
 * 上游为 KV + JSON 字符串存储，此处接口形状保持一致。
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const STORE_NAME = 'lx_music_store'
const TAG = 'PreferencesUtil'
const DOMAIN = 0x0001

class PreferencesUtilImpl {
  private store?: preferences.Preferences

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.store != undefined) {
      return
    }
    this.store = await preferences.getPreferences(context, STORE_NAME)
  }

  private ensure(): preferences.Preferences {
    if (this.store == undefined) {
      throw new Error('PreferencesUtil not initialized, call init() first')
    }
    return this.store
  }

  async getString(key: string): Promise<string> {
    const store = this.ensure()
    try {
      return await store.get(key, '') as string
    } catch (e) {
      // 读取失败（Preferences 文件损坏、存储异常等）时**降级为空值**而不是往上抛：
      // 抛出会让收藏、歌单、设置等所有依赖持久化的功能**静默失效**，
      // 用户只看到「点了没反应」，完全无从判断是数据坏了还是功能坏了。
      hilog.error(DOMAIN, TAG, 'read %{public}s failed: %{public}s', key, JSON.stringify(e))
      return ''
    }
  }

  async setString(key: string, value: string): Promise<void> {
    const store = this.ensure()
    await store.put(key, value)
    await store.flush()
  }

  async remove(key: string): Promise<void> {
    const store = this.ensure()
    await store.delete(key)
    await store.flush()
  }

  async clear(): Promise<void> {
    const store = this.ensure()
    await store.clear()
    await store.flush()
  }
}

export const PreferencesUtil: PreferencesUtilImpl = new PreferencesUtilImpl()