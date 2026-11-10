/**
 * 主题控制器（四期：主题模式落地）
 * themeMode（跟随系统/浅色/深色）→ ApplicationContext.setColorMode，
 * 配合 resources/dark 限定词目录自动切换全部颜色资源。
 */
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ThemeMode } from '../model/AppSettings'

const TAG = 'ThemeController'
const DOMAIN = 0x0001

class ThemeControllerImpl {
  private appContext?: common.ApplicationContext

  init(context: common.Context): void {
    this.appContext = context.getApplicationContext()
  }

  /** 应用主题模式；上下文未就绪时静默跳过（EntryAbility 初始化序列会再应用一次） */
  apply(mode: ThemeMode): void {
    const appContext = this.appContext
    if (appContext == undefined) {
      return
    }
    const colorMode = mode == 'dark'
      ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : (mode == 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    try {
      appContext.setColorMode(colorMode)
      hilog.info(DOMAIN, TAG, 'theme applied: %{public}s', mode)
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'setColorMode failed: %{public}s', JSON.stringify(e))
    }
  }
}

export const ThemeController: ThemeControllerImpl = new ThemeControllerImpl()
