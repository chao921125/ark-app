/**
 * 内置音源集中注册 — 确保各 SourceAdapter 模块被加载、SourceRegistry.register() 顶层语句执行
 * 在 EntryAbility.onWindowStageCreate 中调用 registerBuiltinSources() 一次即可
 */
import { SourceRegistry } from '../api/MusicSource'
import { KwSource } from '../api/kw/KwSource'
import { WySource } from '../api/wy/WySource'
import { KgSource } from '../api/kg/KgSource'
import { TxSource } from '../api/tx/TxSource'
import { MgSource } from '../api/mg/MgSource'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0001
const TAG = 'SourceBootstrap'

/** 引用各源单例，防止 tree-shaking 移除 import 侧的 SourceRegistry.register() 顶层语句 */
export function registerBuiltinSources(): void {
  SourceRegistry.register(KwSource)
  SourceRegistry.register(WySource)
  SourceRegistry.register(KgSource)
  SourceRegistry.register(TxSource)
  SourceRegistry.register(MgSource)
  hilog.info(DOMAIN, TAG, 'builtin sources registered: kw/wy/kg/tx/mg, total=%{public}d', SourceRegistry.all().length)
}
