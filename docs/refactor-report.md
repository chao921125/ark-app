# CCMusic 鸿蒙改造实施报告（MVP）

> 日期：2026-09-01
> 上游：github.com/lyswhut/lx-music-mobile @ master（v1.8.4，React Native 0.73.11）
> 交付：lxmusic-hm（HarmonyOS NEXT / API 12，Stage 模型，ArkTS）

## 一、交付总览

| 阶段 | 结果 |
|---|---|
| 可行性分析 | 完成 → `docs/feasibility-analysis.md`（结论：可行，双路线评估） |
| 改造方案 | 完成 → `docs/refactor-plan.md`（路线 B：ArkTS 原生重写，MVP 范围） |
| 鸿蒙工程 | 完成 → 20 个 ArkTS 源文件 + 完整工程配置 + 12 个 SVG 图标 + 深浅色资源 |
| 构建验证 | 受限：本机无 DevEco Studio/hvigor 工具链（且 shell 进程配额受限），需用户侧 DevEco Studio 5.0+ 打开构建；代码已按 API 12 SDK 规范编写并人工审查两轮 |

## 二、功能实现清单（MVP）

| 功能 | 状态 | 实现文件 | 对应上游 |
|---|---|---|---|
| 本地音乐导入（多选 + 复制进沙箱） | ✅ | utils/FileScanner.ets | core/music/local.ts + react-native-fs |
| 文件名元数据解析（"歌手 - 歌名"） | ✅ | utils/FormatUtil.ets | core/music/utils.ts parseName |
| 播放队列 + 三种播放模式 | ✅ | player/PlayerKernel.ets | core/player/player.ts |
| 进度/时长/seek | ✅ | player/PlayerKernel.ets | core/player/progress.ts |
| 后台播放 + 媒体通知 + 线控 | ✅ | player/MediaSessionController.ets | react-native-track-player |
| 歌单持久化（KV JSON） | ✅ | persistence/ListPersistence.ets | core/list.ts + plugins/storage.ts |
| 设置持久化 + 快照恢复 | ✅ | persistence/SettingPersistence.ets, store/PlayerStore.ets | config/setting.ts, core/init/player |
| LRC 歌词解析（多时间标签/翻译合并） | ✅ | lyric/LyricParser.ets | utils/lrcTools.ts + lrc-file-parser |
| 歌词导入与滚动高亮 | ✅ | lyric/LyricManager.ets, components/LyricView.ets | screens/PlayDetail/*/Lyric |
| 主页列表 + 迷你播放条 + 播放详情页 | ✅ | pages/*, components/* | screens/Home, screens/PlayDetail, components/player/PlayerBar |
| 设置页（模式/字号/行距/清除数据） | ✅ | pages/SettingView.ets | screens/Home/Views/Setting |
| 深浅色自适应 | ✅ | resources/base|dark/element/color.json | theme/（简化） |
| 在线音源扩展点 | ✅ 预留 | api/MusicSource.ets（SourceAdapter/SourceRegistry） | core/apiSource.ts |

## 三、关键技术决策

1. **AVPlayer 切歌策略**：每次切歌 `release + create + prepare + play`（而非 reset 复用），规避 completed 态 seek+play 的不确定性；单曲循环同策略。
2. **导入进沙箱**：picker 返回的 URI 为临时授权，直接引用会过期；复制到 `files/library/` 根治，同时使歌词/封面可用文件 API 自由读写。
3. **状态管理**：AppStorage + @StorageLink 对齐上游 Redux 领域（player/list/setting）；曲目信息以 JSON 串存储触发可靠的 UI 刷新。
4. **元数据 MVP 取舍**：`media.createMediaMetadataGetter` 的 Record 动态类型在 ArkTS 严格模式下风险高，MVP 用文件名约定解析 + 尺寸估算时长（prepare 后由真实 duration 覆盖），mediaMetadata 列入二期。
5. **通知栏时长**：通过 PlayerSnapshotListener.onDurationChanged 在时长就绪后回写 AVPlaybackState.duration。

## 四、自查记录（两轮）

| 类别 | 发现与修复 |
|---|---|
| ArkTS 严格模式 | @Prop 缺本地初始值（MusicListItem）→ 补默认对象字面量 |
| 事件冒泡 | PlayerBar 内播放按钮点击会冒泡展开详情页 → `event.stopPropagation()` |
| API 误用 | promptAction.openToast → showToast；删除不存在的 AbilityStage 导入 |
| 播放器健壮性 | completed 态 seek+play 不可靠 → 重建播放器；getStatus 防 undefined |
| 初始化顺序 | ListStore（设置）在 PlayerKernel.init 前执行导致 playMode 被重置 → 调整顺序 |
| 类型安全 | wantAgent.getWantAgent 参数对象字面量 → 显式 WantAgentInfo 变量 |
| 媒体时长 | 元数据 duration 在切歌瞬间取旧值 → 移除，改由 durationUpdate 回调补写 |
| 构建配置 | ohosTest target 无目录会构建失败 → 移除该 target |

## 五、已知限制与风险

1. **未真机构建**：需 DevEco Studio 5.0+ 构建；如应用图标 SVG 不被接受，替换为同名 PNG（README 已说明）。
2. **SVG 图标风险**：module.json5 的 ability icon 官方推荐 PNG；若构建告警按 README 替换。
3. ** getContext(this) 已标 deprecated（API 12）**：可运行，后续可迁移 `this.getUIContext().getHostContext()`。
4. **多歌单 UI 未暴露**：ListPersistence 已支持多列表，UI 仅默认歌单（四期）。
5. **封面/媒体库元数据**：picUrl 恒为 null（占位封面）；mediaMetadata 二期接入。
6. **协议合规**：保留 Apache 2.0 与上游补充协议；MVP 不含任何在线音源。

## 六、后续路线（对齐 refactor-plan.md 第四节）

- 二期：在线音源（wy/kg/kw，http + cryptoFramework 签名移植 musicSdk）
- 三期：自定义源脚本（JSVM）、PC 同步、桌面歌词（悬浮窗）
- 四期：横竖屏双布局、主题系统（themes.ts 数据移植）、多歌单、本地元数据解析