# 重构实施报告 v2 — 模块解耦 + 播放器功能完善

> 方案见 `refactor-plan-v2.md`。本报告记录**实际做了什么**、**怎么验证的**、以及**未做的部分**。

---

## 一、交付概览

| 类别 | 数量 | 文件 |
|---|---|---|
| 新增 | 7 | `app/PlayerFacade.ets`、`core/queue/PlayQueue.ets`、`core/queue/PlayModePolicy.ets`、`core/volume/VolumeController.ets`、`core/volume/SystemVolume.ets`、`core/source/SourceResolver.ets`、`docs/refactor-plan-v2.md` |
| 重写 | 2 | `player/PlayerKernel.ets`（680→约 700 行，但职责收窄）、`app/PlayerFacade.ets` |
| 瘦身 | 4 | `store/ListStore.ets`、`store/PlayerStore.ets`、`player/MediaSessionController.ets`、`lyric/LyricManager.ets` |
| 改造 | 9 | `pages/PlayDetail.ets`、`components/PlayerBar.ets`、`pages/MyListView.ets`、`pages/SearchView.ets`、`pages/SettingView.ets`(无需改)、`entryability/EntryAbility.ets`、`persistence/ListPersistence.ets`、`README.md`、`.gitignore` |
| 验证工具 | 1 | `tools/verify-player-logic.mjs` |

未改动：`core/source/SourceEngine.ets`（ArkWeb 沙箱）、`api/{kw,wy,kg,tx,mg}`、`sync/`、
`persistence/`、`utils/`、`model/` 的结构与行为。

---

## 二、循环依赖：3 条 → 0 条

### 打断手法

| # | 原环 | 手法 |
|---|---|---|
| 1 | `ListStore ↔ PlayerKernel` | `ListStore.applySettings()` 不再调 `PlayerKernel.setMode()`，改为触发 `onChange` 通知；由 `PlayerFacade` 订阅后推给内核 |
| 2 | `PlayerKernel ↔ PlayerStore` | 内核改为 `configure(cfg: PlayerKernelConfig)` 注入 `getSourceOverride()` 回调，不再 import store |
| 3 | `ListStore → PlayerKernel → PlayerStore → ListStore` | `PlayerStore.restore()` 不再读 `ListStore.getSettings()`，改为由 Facade 以参数 `restoreProgress: boolean` 传入；`saveSnapshot()` 改为接收 `(listId,index,position)`，不再反查内核 |

### 验证（DFS 遍历全部 .ets 的 import 图）

```
改前: 3 条环
改后: 无循环引用 ✓
```

### 分层规则复检

```
player → store : 0 处
lyric  → store : 0 处
store  → player: 0 处
core   → app   : 0 处
core   → pages/components: 0 处
无分层违规 ✓
```

`app/PlayerFacade.ets` 是**唯一**同时依赖 `player/` 与 `store/` 的模块 —— 这正是编排层的位置。

---

## 三、播放器能力补全

### 3.1 新增能力

| 能力 | 实现 | 位置 |
|---|---|---|
| **音量调节** | 0–100 滑块 + 静音切换 + Preferences 持久化（新增键 `player_volume_v1`）+ 切歌后重新下发到 AVPlayer | `core/volume/VolumeController.ets`、`player/PlayerKernel.ets`、`pages/PlayDetail.ets` |
| **播放历史** | 随机模式下「上一首」回到**上一首实际播过的歌**，而非随机；回退导航会消费历史条目，避免连续按原地打转 | `core/queue/PlayQueue.ets`、`player/PlayerKernel.ets` |
| **队列重排** | 队列弹层每项提供上移/下移；当前播放曲目的索引随重排同步修正 | `PlayQueue.move()`、`pages/PlayDetail.ets` |
| **队列清空** | 队列弹层顶部「清空」按钮；清空即停止播放并销毁 AVPlayer | `PlayQueue.clear()`、`pages/PlayDetail.ets` |
| **失败重试** | 新增 `error` 状态；播放详情页在失败时显示提示与「重试」入口 | `player/PlayerKernel.ets`、`pages/PlayDetail.ets` |
| **播放模式持久化** | 在播放详情页切换的模式此前重启即丢失，现已持久化 | `app/PlayerFacade.ets` |

### 3.2 修复的既有缺陷

| 缺陷 | 原因 | 修法 |
|---|---|---|
| **进度条拖不动** | `Slider.value` 直接绑定 `progressTime`，而 `timeUpdate` 每秒回写，拖拽中滑块被覆盖 | 新增拖拽状态机（`dragging` / `dragValue`）：拖拽中锁值，松手才 seek |
| **通知栏进度条不滚动** | AVSession 的 `position` 只在 `onDurationChanged` 写了一次 | 监听接口新增 `onProgressChanged`，媒体会话按 1s 节流回写 |
| **随机模式「上一首」语义错误** | `calcPrevIndex` 在随机模式下也随机取曲 | 引入播放历史栈（见 3.1） |
| **seek 越界** | 未钳制 | 钳制到 `[0, maxTime]`；时长未知时按 0 处理 |
| **音量越界** | 无音量概念 | `VolumeController` 统一钳制到 `[0,100]`；设为非 0 自动取消静音 |
| **音源全部失败被标记为 `completed`** | 语义混淆 | 改为 `error` 状态，可重试 |

### 3.3 边界规则（逐条有确定性断言）

规则清单见 `refactor-plan-v2.md` §3.3，实现在 `core/queue/PlayQueue.ets` 与
`core/queue/PlayModePolicy.ets`（纯逻辑、无 IO）。

---

## 四、第二批（收尾批次）

在第一批完成后继续推进的三项：安全加固、「保存队列为歌单」、系统音量联动。

### 4.1 安全加固：签名密钥与凭据不入库

**问题**：`ccnmusic.p12`（应用签名私钥）、`ccnmusic.csr`、`agconnect-services.json`
（含 `client_secret` / `api_key`）三者**均未被 `.gitignore` 覆盖**，
而仓库有 62 个未跟踪文件、remote 指向 GitHub 公开仓库 —— 一次 `git add .` 即会泄露。
这意味着任何人可用该私钥以 `cn.ccn.music` 的身份签名，并调用 AGC 服务。

**处理**：`.gitignore` 增加

```
/*.p12  /*.p7b  /*.cer  /*.csr  /*.keystore  /*.jks   # 仅锚定仓库根目录
/agconnect-services.json
/.codegenie/        # 自带 .git 的外部工具工作区（会造成嵌套仓库）
/entry/.preview/    # DevEco 预览器构建缓存
```

**未处理的部分（需知悉）**：`build-profile.json5` 里的 `keyPassword` / `storePassword`
是 DevEco 生成的加密口令串，其历史已在 git 中。它们必须与私钥配对才有用，
而私钥已排除、且 DevEco 的正本在 `~/.ohos/config/`（仓库外）。
若本仓库将来要公开，建议把签名配置整体移出版本控制。

### 4.2 「保存队列为歌单」

- `persistence/ListPersistence.ets` 新增 `addMusics(listId, musics)`：批量加入并按 id 去重，
  **整批只落盘一次**（逐首调用 `addMusic` 会造成上百次 Preferences flush）。
- `app/PlayerFacade.ets` 新增 `saveQueueAsList(name)`：编排建单 → 批量写入 → 通知界面刷新。
- `pages/PlayDetail.ets`：播放队列弹层头部新增「保存为歌单」，**内联**展开名称输入（不套弹层）。
- `pages/MyListView.ets`：`likeListRev` 的 `@Watch` 由 `refreshList` 改为 `refreshAll` ——
  原来只刷新当前歌单的内容，歌单**列表**不刷新，导致从其它页面新建的歌单当场看不见。

### 4.3 系统音量联动（平台边界已查清，非臆测）

依据 SDK 类型定义（`@ohos.multimedia.audio.d.ts`）逐项核实：

| 能力 | 结论 |
|---|---|
| AVSession 音量命令 | **不存在**。`'setVolume'` 只出现在投播用的 `AVCastControlCommandType` 中，普通应用的媒体面板不会下发 |
| `audio.setVolume(AudioVolumeType, v)` | 需要 `ohos.permission.ACCESS_NOTIFICATION_POLICY`（用户授权）——为改音量索要通知策略权限不合理，不采用 |
| `setAppVolumePercentage`（API 19+，免权限） | 只对渲染器处于 `APP_INDIVIDUAL` 模式时生效，而 **AVPlayer 未开放设置渲染器 `volumeMode` 的接口**，用了也不确定能否生效，不采用 |
| `AudioVolumeManager.getVolumeByStream` / `isSystemMutedForStream` / `on('streamVolumeChange')` | **API 20+ 正式接口、免权限** → 采用 |

**关键认知**：应用内音量是**应用级增益**，系统媒体流音量叠加在其上 ——
所以通知面板的音量条**本来就在**控制本应用的声音。真正缺的是「用户把系统媒体音量调到 0 后，
应用内音量条仍显示有音量，用户会以为应用坏了」。

**实现**：新增 `core/volume/SystemVolume.ets`（只读 + 监听），`VolumeController` 跟踪系统静音状态，
发布 `playerSystemMuted`；播放详情页在系统静音时给出提示「系统媒体音量已静音，请检查通知面板或控制中心的音量」。

### 4.4 验证台抓出的真实缺陷：歌单 id 碰撞

`ListPersistence.addList` 用 `Date.now()` 生成歌单 id —— **同一毫秒内连续新建两个歌单会得到相同 id，
后建的把先建的顶掉，两个歌单的内容混在一起**。（同文件的 `addListAt` 早有随机后缀，`addList` 漏了。）

修复：新增 `genListId()`，加随机后缀并做冲突检查；`addList` 与 `addListAt` 共用。

该缺陷由验证台断言「连续新建歌单：id 不相同」发现，修复前失败、修复后通过。

---

## 五、验证

### 5.1 编译

```
DEVECO_SDK_HOME=... hvigorw.js --mode module -p product=default assembleHap
→ BUILD SUCCESSFUL
```

产物：`entry/build/default/outputs/default/entry-default-signed.hap`

### 5.2 纯逻辑确定性验证台 `tools/verify-player-logic.mjs`

直接运行**未经改写的真实源码**（仅把 import 语句改写为 `import type` / 补 `.ts` 扩展名 /
把 `@kit.PerformanceAnalysisKit` 换成桩件 / 把 `PreferencesUtil` 换成内存实现），Node 原生类型剥离执行。

覆盖：`core/queue/PlayModePolicy.ets`、`core/queue/PlayQueue.ets`、
`persistence/ListPersistence.ets`、`model/SongList.ets`。

```
通过 63 项
全部通过 ✓
```

### 5.3 循环依赖与分层

```
循环依赖: 无 ✓
分层违规: 0 处 ✓
```

### 5.4 变异测试（证明断言不是假阳性）

| 变异 | 实测 |
|---|---|
| `removeAt` 移除当前曲后不修正 `nextIndex` | ✗ 2 项失败 ✓ |
| `move` 时当前索引不跟随 | ✗ 2 项失败 ✓ |
| `prevIndex` 的环绕公式写错 | ✗ 2 项失败 ✓ |

---

## 六、兼容性与风险

| 项 | 说明 |
|---|---|
| 数据 | Preferences 键全部沿用，仅**新增** `player_volume_v1`；旧数据不受影响 |
| 存档 | `MusicInfo` / `SongList` / `play_snapshot_v1` 结构均未改动；**歌单 id 生成规则变更**（加随机后缀），旧歌单 id 不受影响 |
| API | `PlayerKernel` 对外方法只增不减；`MediaSessionController.init()` 新增了必填的 `config` 参数（唯一一处签名变更，仅 `EntryAbility`/`PlayerFacade` 调用）；`ListPersistence` 新增 `addMusics` / `genListId`（私有） |
| 沙箱 | `SourceEngine` 与 ArkWeb 桥接一行未改，仅由 `SourceResolver` 单向调用 |
| 行为变化 | 随机模式「上一首」由随机改为回到上一首实际播过的歌（**有意修正**）；播放详情页切换的模式现在会被持久化；系统媒体静音时播放页新增提示 |
| 平台限制 | AVSession 无音量事件，普通应用无法接管通知面板的音量条（详见 §4.3） |

---

## 七、后续可做

- 把 `tools/verify-player-logic.mjs` 接入 `ohosTest`（当前 ohosTest 已被删除，需重建）
- 队列本身仍是内存副本，重启后丢失（已能另存为歌单，歌单本身持久化）
- 若仓库要公开：把签名配置整体移出版本控制（见 §4.1）

