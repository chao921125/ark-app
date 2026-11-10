/**
 * 桌面歌词悬浮窗管理器（三期）— 基于 window.createWindow(TYPE_FLOAT) 的全局悬浮窗
 * 双模式设计：
 *  - 设备允许（ACL 签名授予 ohos.permission.SYSTEM_FLOAT_WINDOW）→ 全局悬浮窗（pages/FloatLyricPage），
 *    应用退后台/切其他应用时歌词仍可见（对齐上游桌面歌词单行模式）；
 *  - 权限缺失/设备不支持（错误码 201/801/1300004）→ 返回 false，回落应用内 FloatLyricBar。
 * 状态通过 AppStorage('floatLyricWindowActive') 通知 UI（应用内条与悬浮窗互斥）。
 */
import { window, display } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'FloatLyricWindow'
const DOMAIN = 0x0001

const WIN_NAME = 'lx_float_lyric'
/** 歌词条高度（vp→px 由密度换算） */
const BAR_HEIGHT_VP = 44

/** 歌词条初始位置（px）：横向 7% 屏宽、纵向 12% 屏高 */
function initialBarRect(): BarRect {
  try {
    const d = display.getDefaultDisplaySync()
    return {
      x: Math.floor(d.width * 0.07),
      y: Math.floor(d.height * 0.12),
      width: Math.floor(d.width * 0.86),
      height: Math.floor(d.height * 0.05 + BAR_HEIGHT_VP * (d.densityPixels > 0 ? d.densityPixels : 3))
    }
  } catch (ignored) {
    return { x: 20, y: 200, width: 900, height: 132 }
  }
}

interface BarRect {
  x: number
  y: number
  width: number
  height: number
}

class FloatLyricWindowImpl {
  private context?: common.UIAbilityContext
  private win?: window.Window
  private creating: boolean = false

  /** EntryAbility 启动时注入 context（对齐 MediaSessionController.init 模式） */
  init(context: common.UIAbilityContext): void {
    this.context = context
  }

  /** 悬浮窗是否已创建（UI 据此互斥显示应用内歌词条） */
  isWindowActive(): boolean {
    return this.win != undefined
  }

  /** 供悬浮窗页面拖动用：按名称查找窗口 */
  findWindow(): window.Window | undefined {
    try {
      return window.findWindow(WIN_NAME)
    } catch (e) {
      return undefined
    }
  }

  /**
   * 同步开关状态：开 → 尝试创建悬浮窗（失败回落应用内，返回 false）；
   * 关 → 销毁悬浮窗。UI 层通过 floatLyricWindowActive 感知实际模式。
   */
  async syncState(on: boolean): Promise<boolean> {
    if (!on) {
      await this.destroy()
      AppStorage.setOrCreate<boolean>('floatLyricWindowActive', false)
      return true
    }
    const ok = await this.tryCreate()
    AppStorage.setOrCreate<boolean>('floatLyricWindowActive', ok)
    return ok
  }

  private async tryCreate(): Promise<boolean> {
    if (this.win != undefined || this.creating) {
      return this.win != undefined
    }
    if (this.context == undefined) {
      hilog.warn(DOMAIN, TAG, 'context not init, fallback to in-app bar')
      return false
    }
    this.creating = true
    try {
      const config: window.Configuration = {
        name: WIN_NAME,
        windowType: window.WindowType.TYPE_FLOAT,
        ctx: this.context
      }
      const w = await window.createWindow(config)
      const rect = initialBarRect()
      await w.resize(rect.width, rect.height)
      await w.moveTo(rect.x, rect.y)
      await w.setUIContent('pages/FloatLyricPage')
      await w.setWindowBackgroundColor('#00000000')
      await w.showWindow()
      this.win = w
      hilog.info(DOMAIN, TAG, 'float lyric window created')
      return true
    } catch (e) {
      const err = e as BusinessError
      // 201=权限缺失 / 801=设备不支持 / 1300004=窗口类型无效 → 回落应用内歌词条
      hilog.error(DOMAIN, TAG, 'create float window failed: %{public}d %{public}s',
        err.code ?? -1, err.message ?? '')
      this.win = undefined
      return false
    } finally {
      this.creating = false
    }
  }

  private async destroy(): Promise<void> {
    const w = this.win
    this.win = undefined
    if (w == undefined) {
      return
    }
    try {
      await w.destroyWindow()
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'destroy float window failed: %{public}s', JSON.stringify(e))
    }
  }
}

export const FloatLyricWindow: FloatLyricWindowImpl = new FloatLyricWindowImpl()