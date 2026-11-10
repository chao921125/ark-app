# 重构方案 v2 — 模块解耦 + 播放器功能完善

> 承接 `refactor-plan.md`（一期：洛雪功能移植）与 `convergence-report.md`（二期：工程收敛）。
> 本期目标：**打断现有 3 条模块循环依赖**，把职责混杂的模块拆成边界清晰的能力单元，
> 并补全播放器的缺失能力与既有缺陷。

---

## 一、现状盘点（代码实测，非推测）

### 1.1 循环依赖（DFS 检测 `entry/src/main/ets` 全部 60 个 .ets）

```
CYCLE: store/ListStore.ets      → player/PlayerKernel.ets → store/ListStore.ets
CYCLE: player/PlayerKernel.ets  → store/PlayerStore.ets   → player/PlayerKernel.ets
CYCLE: store/ListStore.ets      → player/PlayerKernel.ets → store/PlayerStore.ets → store/ListStore.ets
```

根因是**双向调用**：

| 调用方 | 被调方 | 触发点 | 性质 |
|---|---|---|---|
| `ListStore` | `PlayerKernel` | `applySettings()` 里 `setMode` / `setPlayQuality` | 设置层反向驱动播放器 |
| `PlayerKernel` | `ListStore` | `playIndexInternal()` 里读 `getSettings().sourcePriority` | 播放器反向读设置层 |
| `PlayerKernel` | `PlayerStore` | `playIndexInternal()` 里读 `getSourceOverride()` | 播放器反向读持久层 |
| `PlayerStore` | `PlayerKernel` | `playFromList()` 调 `setList()`；`saveSnapshotPosition()` 反查 `getIndex()`/`getProgressSec()`；`restore()` 调 `setListWithoutPlay()` | 持久层反向驱动播放器 |
| `PlayerStore` | `ListStore` | `restore()` 里读 `getSettings().restorePlayProgress` | 持久层反向读设置层 |
| `MediaSessionController` | `PlayerStore` | 切歌/暂停时保存快照 | 媒体会话层反向依赖持久层 |
| `LyricManager` | `ListStore` | 读 `sourcePriority` | 歌词层反向读设置层 |

### 1.2 职责混杂

- `player/PlayerKernel.ets`（680 行）同时承担：AVPlayer 生命周期、播放队列容器、音质降级解析、
  音源候选链调度、状态发布。音源调度（`playIndexInternal` 内 80 行）与队列逻辑都不属于「播放器内核」。
- `lyric/LyricManager.ets` 直接依赖 `SourceEngine` + `SourceRegistry` + `ListStore` + `FileScanner`，
  歌词层自己去遍历音源候选链，与播放器各写一份遍历逻辑。
- `pages/PlayDetail.ets`（658 行）直接编排 Kernel / Store / MediaSession / LyricManager / SourceRegistry，
  UI 层承担了应用编排职责。

### 1.3 播放器能力现状 vs 目标

| 目标能力 | 现状 | 判定 | 差距定位 |
|---|---|---|---|
| 播放 / 暂停 | `toggle()` / `pause()`，`PlayerBar` + `PlayDetail` 均有按钮 | ✅ 已有 | loading 中点击被静默忽略；失败后无可重试入口 |
| 上一首 / 下一首 | `skipPrev()` / `skipNext()`，`PlayDetail` 有按钮 | ⚠️ 部分 | **随机模式下「上一首」返回随机曲目**，语义错误；无历史栈 |
| 进度条拖拽 | `PlayDetail` 有 `Slider`，`onChange` 在 End/Click 时 seek | ⚠️ **有缺陷** | `Slider.value` 直接绑定 `progressTime`，而 `timeUpdate` 每秒回写 → **拖拽过程中滑块被回写覆盖，无法稳定拖动** |
| 音量调节 | 无任何音量概念 | ❌ **完全缺失** | 需新增状态、持久化、AVPlayer 应用、UI 滑块、静音切换 |
| 播放列表管理 | `removeAt()` + 队列弹层 | ⚠️ 部分 | 缺重排序、缺清空；队列仅内存副本，不持久化 |
| 循环 / 随机模式 | `setMode()` 三模式，`PlayDetail` + 设置页均可切换 | ✅ 已有 | 单曲循环下手动切歌行为未在代码中显式定义 |
| 播放状态同步 | `AppStorage` + `AVSession` | ⚠️ 部分 | AVSession 的 `position` 只在 `onDurationChanged` 写一次 → **通知栏进度条不滚动** |
| 异常与边界 | `playToken` 防切歌串扰、失败 toast | ⚠️ 部分 | 缺 `error` 状态、seek 越界、音量越界、连续点击 |

**可复用点（不重写）**：`playToken` 代次机制、`waitForInitialized` 单监听 waiter、
`SourceEngine` ArkWeb 沙箱、`LyricParser`、`MediaSessionController` 的 AVSession 接线、
`QUALITY_LADDER` 音质降级链、`PreferencesUtil` 持久化底座。

---

## 二、目标架构

### 2.1 分层与依赖规则

```
┌─ L4 表现层   pages/ · components/            只允许 import L3
├─ L3 编排层   app/PlayerFacade                可 import L2；L2 不得反向 import
├─ L2 能力层   core/ · player/ · lyric/ · api/ · sync/
└─ L1 数据层   model/ · persistence/ · utils/   不依赖任何上层
```

**硬规则**：同层之间不互相 import（编排层除外，它是被依赖的汇聚点）；L2 不得 import L3/L4。

### 2.2 模块划分

```
entry/src/main/ets/
├── app/                             【新增·编排层】
│   └── PlayerFacade.ets             播放域唯一入口：装配依赖注入 + 编排 Kernel/Store/Volume
├── core/                            【能力层】
│   ├── queue/PlayQueue.ets          【新增】播放队列纯逻辑（增删改排/索引/上下曲/历史栈）
│   ├── queue/PlayModePolicy.ets     【新增】播放模式的上下曲策略（纯函数）
│   ├── volume/VolumeController.ets  【新增】音量状态 + 持久化 + 应用到 AVPlayer
│   ├── source/SourceResolver.ets    【新增】统一音源入口（custom + 内置源：直链/歌词/搜索）
│   ├── source/SourceEngine.ets      （不变）洛雪自定义源 ArkWeb 沙箱
│   ├── source/{SourceStore,LxHttp,LxMetadata,LxTypes}.ets  （不变）
│   └── music/LxCrypto.ets           （不变）
├── player/                          （瘦身）
├── lyric/                           （瘦身）
├── store/                           （瘦身）
├── model/ · persistence/ · utils/ · api/ · sync/   （基本不变）
└── pages/ · components/             （改走 Facade）
```

### 2.3 各模块职责与对外接口

| 模块 | 职责（单一） | 对外接口 | 依赖 |
|---|---|---|---|
| `core/queue/PlayQueue` | 队列数据与索引的纯逻辑，**无任何 IO / 无平台 API** | `setList/getList/size/getIndex/setIndex/getCurrent/removeAt/move/insertAt/replaceAt/clear/pushHistory/popHistory/peekHistory/historyIndexInQueue/indexOfId` | `model/MusicInfo` |
| `core/queue/PlayModePolicy` | 上下曲索引的**纯函数**（无状态） | `nextIndex(mode,curIndex,size)` `prevIndex(mode,curIndex,size)` | `model/AppSettings`（仅取 PlayMode 类型） |
| `core/source/SourceResolver` | 统一「按候选链取直链 / 取歌词 / 搜索」 | `setPriority/getPriority/buildCandidates/getMusicUrlFrom/getLyricFrom/search` | `core/source/SourceEngine`, `api/MusicSource`, `model/MusicInfo` |
| `core/volume/VolumeController` | 音量数值管理（0–100）+ 静音 + 持久化 + 下发 | `init/get/getUserVolume/isMuted/set/toggleMute/onChange` | `persistence/PreferencesUtil` |
| `player/PlayerKernel` | AVPlayer 生命周期 + 播放状态机 + 队列委托 + 音质降级 | `init/configure/restoreVolume/toggle/pause/seek/skipNext/skipPrev/setList/playIndex/removeAt/moveInQueue/clearQueue/replaceCurrent/setMode/setPlayQuality/setVolume/getVolume/toggleMute/getStatus` | `core/queue`, `core/source/SourceResolver`, `core/volume`, `model/`（**不再依赖 store**） |
| `player/MediaSessionController` | AVSession + 长时任务接线 | `init/destroy/syncPlaybackPosition` | `player/PlayerKernel`（**不再依赖 store**） |
| `store/ListStore` | 设置与歌单的**内存状态 + 持久化**，变更时发通知 | `getSettings/applySettings/onChange/offChange/init/setShowFloatLyric/reload` | `persistence/`, `model/`, `utils/ThemeController`, `lyric/FloatLyricWindow` |
| `store/PlayerStore` | 播放快照与音源覆盖的**纯持久化** | `saveSnapshot/loadSnapshot/restore/setSourceOverride/getSourceOverride/removeSourceOverride` | `persistence/`, `model/` |
| `lyric/LyricManager` | 歌词加载与行定位 | `loadForMusic/findLineIndex` | `core/source/SourceResolver`, `lyric/LyricParser`, `utils/FileScanner` |
| `app/PlayerFacade` | 播放域**编排**：装配注入、跨层协调、快照时机 | 见 §3.2 | L2 全部 |

### 2.4 循环依赖如何被打断

```
改前:  ListStore ←→ PlayerKernel ←→ PlayerStore        （3 条环）
改后:  ListStore ─┐
                  ├→ PlayerFacade → PlayerKernel → core/*
       PlayerStore ┘                  │
                                     └→ core/queue, core/source, core/volume
```

三个具体手法：

1. **依赖倒置（配置注入）**：`PlayerKernel` 不再 import `ListStore`/`PlayerStore`，
   改为 `configure(cfg: PlayerKernelConfig)` 注入 `getSourcePriority()` / `getSourceOverride()` 回调。
   Kernel 只认函数签名，不认具体 Store 实现 → 测试时可注入假实现。
2. **快照时机上移**：`PlayerStore` 不再反查 Kernel（`getIndex()`/`getProgressSec()`），
   改由 Facade 在切歌/暂停时把 `(listId, index, position)` 作为**参数**传进去。
3. **设置下发改为通知**：`ListStore.applySettings()` 不再直接调 `PlayerKernel.setMode()`，
   改为触发 `onChange` 回调；由 Facade 订阅后推给 Kernel。

> **为什么不用事件总线**（备选方案，已否决）：事件总线能打断静态依赖，但会把依赖变成隐式的运行时约定，
> 跨模块的调用顺序无法静态检查，且本项目已经出现过「事件竞态导致初始化丢失」类问题
> （见 `SourceEngine` 中 `playToken` / `initPromise` 的注释）。Facade 是显式依赖，可读、可查、可测。

---

## 三、播放器功能补全

### 3.1 能力清单（目标态）

| 能力 | 实现要点 | 状态 |
|---|---|---|
| 播放 / 暂停 | `toggle()` 按 `idle/loading/playing/paused/completed/error` 分派；`error` 态点击 → 重试当前曲 | 改造 |
| 上一首 | **新增播放历史栈**：随机模式下「上一首」回到历史曲目而非随机 | **新增** |
| 下一首 | 按模式计算；`singleLoop` 只影响**自动续播**，手动切歌照常切下一曲 | 明确语义 |
| 进度条拖拽 | **新增拖拽状态机** `idle → dragging → seeking`：拖拽中滑块值不再被 `timeUpdate` 回写 | **修复缺陷** |
| 音量调节 | **新增** `VolumeController`：0–100 滑块 + 静音切换 + Preferences 持久化 + 切歌后重新下发 | **新增** |
| 播放列表管理 | **新增** 队列重排序（上移/下移）、**新增** 清空队列；保留移除与点播 | **新增** |
| 循环 / 随机模式 | 三模式齐备；随机模式配合历史栈 | 已有 + 增强 |
| 播放状态同步 | AVSession `position` **节流**（1s）回写 → 通知栏进度条滚动 | 修复 |
| 异常与边界 | 新增 `error` 状态；seek 钳制到 `[0, duration]`；音量钳制到 `[0,100]`；空队列操作直接返回 | 补全 |

### 3.2 PlayerFacade 对外接口（UI 唯一入口）

```ts
// 播放控制
toggle() / pause() / seek(sec) / skipNext() / skipPrev() / retry()
playIndex(index) / playFromList(listId, musics, index)
// 队列
getQueue() / getQueueIndex() / removeAt(i) / moveInQueue(from, to) / clearQueue()
// 模式与音质
getMode() / setMode(mode) / getPlayQuality() / setPlayQuality(q)
// 音量
getVolume() / setVolume(v) / toggleMute() / isMuted()
// 换源
replaceCurrent(music) / setSourceOverride(songId, sourceId)
// 快照
saveSnapshot() / restore()
```

### 3.3 边界与异常规则（确定性，可单测）

| 场景 | 规则 |
|---|---|
| 队列为空时 skipNext/skipPrev/playIndex | 直接返回，不改状态 |
| seek 目标越界 | 钳制到 `[0, maxTime]`；`maxTime` 未知（0）时忽略 |
| 音量越界 | 钳制到 `[0,100]`；静音态下设音量自动取消静音 |
| 切歌期间旧异步回调 | `playToken` 代次不匹配即丢弃（沿用现有机制） |
| 音源全部失败 | 状态置 `error`，弹提示，UI 显示可点击重试 |
| `loading` 中重复点击 | 忽略并记日志，避免与起播流程竞态 |
| 随机模式「上一首」 | 优先回到历史栈栈顶；历史为空时退回随机 |
| 单曲循环 | 仅作用于**播完自动续播**；手动下一首照常切 |
| 队列清空 | 停止播放、销毁 AVPlayer、状态置 `idle` |
| 切歌后音量 | 新建 AVPlayer 后重新下发当前音量 |

---

## 四、文件改动清单

### 4.1 新增（6 个）

| 文件 | 内容 |
|---|---|
| `app/PlayerFacade.ets` | 编排层：依赖注入装配 + 跨层协调 |
| `core/queue/PlayQueue.ets` | 队列纯逻辑 + 历史栈 |
| `core/source/SourceResolver.ets` | 统一音源入口（直链 / 歌词 / 搜索） |
| `core/volume/VolumeController.ets` | 音量状态 + 持久化 + 下发 |
| `core/queue/PlayModePolicy.ets` | 播放模式的上下曲策略（纯函数，便于单测） |
| `docs/refactor-plan-v2.md` | 本方案文档 |

### 4.2 重写（2 个）

| 文件 | 改动 |
|---|---|
| `player/PlayerKernel.ets` | 去掉 `ListStore`/`PlayerStore`/`SourceEngine`/`SourceRegistry` 导入；队列委托 `PlayQueue`；音源委托 `SourceResolver`；新增音量下发、`error` 状态、seek 钳制 |
| `app/PlayerFacade.ets` | 新增（见 4.1） |

### 4.3 修改（9 个）

| 文件 | 改动 |
|---|---|
| `store/ListStore.ets` | 去掉 `PlayerKernel` 导入；`applySettings` 改发 `onChange` 通知 |
| `store/PlayerStore.ets` | 去掉 `PlayerKernel`/`ListStore` 导入；`saveSnapshot` 收参数；`restore` 返回数据而非直接驱动内核 |
| `player/MediaSessionController.ets` | 去掉 `PlayerStore` 导入；快照保存改为注入回调；position 节流回写 |
| `lyric/LyricManager.ets` | 去掉 `ListStore`/`SourceEngine`/`SourceRegistry` 导入；改走 `SourceResolver` |
| `pages/PlayDetail.ets` | 改走 Facade；新增音量滑块 + 静音按钮；进度条拖拽状态机；队列重排/清空按钮；错误态重试 |
| `components/PlayerBar.ets` | 改走 Facade |
| `pages/MyListView.ets` / `pages/SearchView.ets` | `PlayerStore.playFromList` → `PlayerFacade.playFromList` |
| `pages/SettingView.ets` | 播放模式 / 音质改走 Facade（保持持久化行为一致） |
| `entryability/EntryAbility.ets` | 初始化顺序改为 Facade 统一装配 |

---

## 五、实施步骤

1. **新增能力层**：`PlayQueue` → `PlayModePolicy` → `SourceResolver` → `VolumeController`（自底向上，先纯逻辑后有 IO）
2. **重写内核**：`PlayerKernel` 瘦身为依赖注入形态，接上 `PlayQueue` / `SourceResolver` / `VolumeController`
3. **瘦身仓储与旁路**：`ListStore` / `PlayerStore` / `MediaSessionController` / `LyricManager` 去掉反向依赖
4. **新增编排层**：`PlayerFacade` 装配全部注入，把 `EntryAbility` 的初始化收敛到一处
5. **改造 UI**：页面/组件改走 Facade，补齐音量、队列管理、拖拽状态机、错误态
6. **验证**：hvigor `assembleHap` 编译通过 + DFS 复检无循环引用 + 逐条核对 §3.3 边界规则

---

## 六、兼容性与风险

| 项 | 说明 |
|---|---|
| 数据兼容 | Preferences 键全部沿用，仅**新增** `player_volume_v1`；旧数据不受影响 |
| 存档兼容 | `MusicInfo` / `SongList` 模型不动；`play_snapshot_v1` 结构不动 |
| API 兼容 | `PlayerKernel` 对外方法**只增不减**；`MediaSessionController` / `ListStore` 保留原方法签名 |
| 沙箱兼容 | `SourceEngine` 与 ArkWeb 桥接**一行不改**，仅由 `SourceResolver` 单向调用 |
| 风险点 | 「上一首」在随机模式下行为变化（随机 → 历史栈），属**有意的体验修正**；队列重排序为新增交互 |
| 构建验证 | `DEVECO_SDK_HOME=... hvigorw assembleHap` 全量编译，编译错误即视为未完成 |
