/**
 * 应用级仓库 — 设置与歌单的全局入口（对齐上游 store/setting + store/list）
 *
 * 【模块边界】本模块只管「设置与歌单的状态」，不碰播放器。
 * 设置变更通过 onChange 通知订阅者，由编排层（app/PlayerFacade）推给播放器，
 * 因此 store/ 与 player/ 之间不存在循环引用。
 */
import { AppSettings, DEFAULT_SETTINGS } from '../model/AppSettings'
import { SettingPersistence } from '../persistence/SettingPersistence'
import { ListPersistence } from '../persistence/ListPersistence'
import { ThemeController } from '../utils/ThemeController'
import { FloatLyricWindow } from '../lyric/FloatLyricWindow'

/** 设置变更通知 */
export type SettingsChangeListener = (settings: AppSettings) => void

class ListStoreImpl {
  private settings: AppSettings = DEFAULT_SETTINGS
  private listeners: SettingsChangeListener[] = []

  getSettings(): AppSettings {
    return this.settings
  }

  /**
   * 应用一份新设置并通知订阅者。
   * 注意：调用方可能直接修改 getSettings() 返回的对象后再传进来（沿用既有调用习惯），
   * 因此这里保存的是同一个对象引用，通知时读取到的即为最新值。
   */
  applySettings(s: AppSettings): void {
    this.settings = s
    ThemeController.apply(s.themeMode)
    this.notifyChanged()
  }

  /** 订阅设置变更（编排层用它把播放模式/音质推给播放器内核） */
  onChange(listener: SettingsChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  /** 取消订阅设置变更 */
  offChange(listener: SettingsChangeListener): void {
    const idx: number = this.listeners.indexOf(listener)
    if (idx >= 0) {
      this.listeners.splice(idx, 1)
    }
  }

  private notifyChanged(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      try {
        this.listeners[i](this.settings)
      } catch (ignored) {
        // 单个订阅者异常不影响其他订阅者
      }
    }
  }

  /** 启动初始化：加载设置并应用 */
  async init(): Promise<void> {
    this.settings = await SettingPersistence.load()
    ThemeController.apply(this.settings.themeMode)
    AppStorage.setOrCreate<number>('lyricFontSize', this.settings.lyricFontSize)
    AppStorage.setOrCreate<number>('lyricLineGap', this.settings.lyricLineGap)
    AppStorage.setOrCreate<boolean>('showFloatLyric', this.settings.showFloatLyric)
    this.notifyChanged()
  }

  /** 悬浮歌词开关（持久化 + 双模式同步：真悬浮窗优先，失败回落应用内歌词条） */
  async setShowFloatLyric(on: boolean): Promise<void> {
    this.settings.showFloatLyric = on
    AppStorage.setOrCreate<boolean>('showFloatLyric', on)
    try {
      await SettingPersistence.save(this.settings)
    } catch (ignored) {
      // 持久化失败不影响本次会话的开关状态
    }
    // 真悬浮窗创建/销毁（权限缺失或设备不支持时内部回落，floatLyricWindowActive=false）
    const windowOk = await FloatLyricWindow.syncState(on)
    if (on) {
      AppStorage.setOrCreate<boolean>('floatLyricWindowActive', windowOk)
    }
  }

  /** 清除数据后重新加载歌单 */
  async reload(): Promise<void> {
    await ListPersistence.load()
  }
}

export const ListStore: ListStoreImpl = new ListStoreImpl()
