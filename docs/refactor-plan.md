# CCMusic 鸿蒙改造方案（路线 B：ArkTS 原生重写 — MVP）

> 上游：github.com/lyswhut/lx-music-mobile @ master（v1.8.4）
> 交付目标：可被 DevEco Studio（HarmonyOS NEXT / API 12+）直接打开构建运行的鸿蒙工程
> 功能范围：本地音乐播放核心（导入/播放/列表/歌词/设置/后台播放与媒体控制）+ 在线音源扩展点

## 一、架构映射（原项目 → 鸿蒙工程）

| 原项目（React Native） | 鸿蒙工程（ArkTS Stage 模型） | 说明 |
|---|---|---|
| `src/types/music.d.ts`（LX.Music.MusicInfo） | `ets/model/MusicInfo.ets` | 数据模型形状对齐（id/name/singer/source/interval/meta），local 源 songId=文件路径 |
| `src/core/player/*`（播放状态机） | `ets/player/PlayerKernel.ets` | AVPlayer 队列封装：setList/play/pause/skip/seek/playMode；状态机 idle→initialized→prepared→playing→paused→completed |
| `react-native-track-player`（fork） | `ets/player/PlayerKernel.ets` + `MediaSessionController.ets` | 播放内核用 AVPlayer；通知栏/线控/媒体会话用 AVSession；后台用长时任务 |
| `src/plugins/storage.ts` + AsyncStorage | `ets/persistence/PreferencesUtil.ets` | KV 持久化；歌单/设置 JSON 序列化存储（与原项目 KV 方案一致） |
| `src/store/*`（Redux 自建 store） | ArkTS AppStorage/@StorageLink + `ets/store/*Store.ets` | 播放状态、歌单、设置三大领域；跨组件事件用 @ohos.events.emitter（对齐 `src/event/Event.ts`） |
| `src/utils/lrcTools.ts` + `lrc-file-parser` | `ets/lyric/LyricParser.ets` | 纯算法移植：LRC 时间标签解析、多时间标签行、进度→当前行定位 |
| `src/screens/Home`（列表/PlayerBar） | `ets/pages/Index.ets` + `ets/components/*` | Tabs（我的列表/设置）+ 底部常驻 PlayerBar |
| `src/screens/PlayDetail`（播放详情） | `ets/pages/PlayDetail.ets`（全屏覆盖层） | 封面/进度/控制按钮/滚动歌词 |
| `src/screens/Home/Views/Setting` | `ets/pages/SettingView.ets` | 播放模式/外观/数据管理/关于 |
| 本地音乐读取（react-native-local-media-metadata + fs） | `ets/utils/FileScanner.ets` + @ohos.multimedia.mediaMetadata | 文件选择导入 + 元数据提取（标题/歌手/专辑/封面/时长） |
| `src/utils/musicSdk/*`（六音源 SDK） | `ets/api/MusicSource.ets`（抽象） + `LocalSource`（内置） | **预留扩展点**：search/getMusicUrl/getLyric 接口；在线源按 SDK 逐平台移植（二期） |
| `src/utils/nativeModules/userApi`（QuickJS 自定义源） | 二期：JSVM API | 全功能对齐的最大风险项，不在 MVP |
| 桌面歌词（android/lyric 原生自绘） | 二期：悬浮窗 window + ArkUI | 不在 MVP |
| `react-native-navigation` | ArkUI Navigation/Tabs/Stack | 无需三方路由 |

## 二、工程结构

```
lxmusic-hm/
├── AppScope/app.json5                    # 应用信息（bundleName: cn.ccn.music.harmony）
├── build-profile.json5                   # 工程级构建配置（API 12）
├── hvigor/hvigor-config.json5
├── oh-package.json5
├── docs/
│   ├── feasibility-analysis.md           # 可行性分析
│   ├── refactor-plan.md                  # 本方案
│   └── refactor-report.md                # 改造实施报告
└── entry/src/main/
    ├── module.json5                      # 权限（KEEP_BACKGROUND_RUNNING/INTERNET）、backgroundModes:[audioPlayback]
    ├── resources/base/
    │   ├── element/{color.json,string.json}
    │   ├── media/{app_icon.svg,play_pause... 用系统符号替代}
    │   └── profile/main_pages.json
    └── ets/
        ├── entryability/EntryAbility.ets # 应用入口：初始化存储→恢复歌单/设置→恢复媒体会话
        ├── pages/
        │   ├── Index.ets                 # 主页：Stack{ Tabs + PlayDetail 覆盖层 + PlayerBar }
        │   └── PlayDetail.ets            # 播放详情（封面/歌词/控制）
        ├── components/
        │   ├── PlayerBar.ets             # 迷你播放条（对齐 components/player/PlayerBar）
        │   ├── MusicListItem.ets         # 歌曲行
        │   └── LyricView.ets             # 滚动歌词（高亮当前行）
        ├── player/
        │   ├── PlayerKernel.ets          # AVPlayer 播放内核（单例）
        │   ├── MediaSessionController.ets# AVSession + 长时任务 + 通知栏媒体控制
        │   └── PlayMode.ets              # listLoop/listRandom/singleLoop
        ├── model/{MusicInfo.ets,SongList.ets,AppSettings.ets}
        ├── store/{PlayerStore.ets,ListStore.ets,SettingStore.ets}  # AppStorage 键 + 全局单例
        ├── persistence/{PreferencesUtil.ets,ListPersistence.ets,SettingPersistence.ets}
        ├── lyric/LyricParser.ets
        ├── api/{MusicSource.ets,LocalSource.ets}  # 音源扩展点
        └── utils/{FileScanner.ets,FormatUtil.ets}
```

## 三、关键设计

### 1. 播放内核（PlayerKernel，AVPlayer 状态机）

```
setList(musics, startIndex)
  ├─ stop/释放旧 player → new AVPlayer
  ├─ fdSrc = 打开本地文件 fd（fs.open filePath）
  ├─ on('stateChange') → 状态回写 AppStorage（playerStatus）
  ├─ on('timeUpdate')  → 500ms 节流写 progressTime
  └─ on('seekDone') → 同步 seekTime
playMode: listLoop（列表循环，末尾回首曲）/ listRandom（随机）/
          singleLoop（单曲循环，on complete 重 seek(0)+play）
切歌：skipNext/skipPrev → 换 index → reset → fdSrc → prepare → play
```

### 2. 后台播放与媒体控制（MediaSessionController）

- `avSession.createAVSession(ctx, 'lx-music', 'audio')`
- `setAVMetadata`：标题/歌手/专辑/时长/封面（沙箱内 pic 路径）
- `setAVPlaybackState`：state + position + speed
- 监听命令：play/pause/playNext/playPrevious/seek/stop → 转发 PlayerKernel
- 长时任务：`backgroundTaskManager.startBackgroundRunning(id, AUDIO_PLAYBACK)`，播放中启动、暂停时停止
- 权限：`ohos.permission.KEEP_BACKGROUND_RUNNING`

### 3. 状态管理（对齐 Redux 领域划分）

AppStorage 键：`playerStatus / progressTime / maxTime / currentMusic / playMode / playList / listId / settings`
组件内 `@StorageLink` 双向同步；跨模块通知用 `emitter`（事件名对齐原 `src/event/*Event.ts` 命名）。

### 4. 歌词（LyricParser）

移植 `lrcTools.ts` 正则逻辑：
- `timeFieldExp = /^(?:\[[\d:.]+\])+/`、`timeExp = /\d{1,3}(:\d{1,3}){0,2}(?:\.\d{1,3})/g`
- `parse(text) → LyricLine[{ time(ms), text }]`（按时间排序）
- 播放进度二分定位当前行；翻译歌词按同时间标签合并
- 来源：① 与音频同目录同名 `.lrc`（导入到沙箱时一并复制）② 设置页手动关联

### 5. 本地音乐导入（FileScanner）

- 单文件/多文件：`DocumentViewPicker`（`select` 文件类型 audio）→ 返回 fileUri
- 导入策略：复制音频到应用沙箱 `files/library/`（附带同名 .lrc）→ 元数据提取（mediaMetadata：标题/歌手/专辑/时长/封面图落盘）→ 构建 MusicInfo（songId=沙箱路径）→ 写入"默认列表"
- 好处：持久可访问（picker 临时授权会过期），歌词/封面可用文件系统自由读取

### 6. 音源扩展点（MusicSource 抽象）

```ts
export interface SourceAdapter {
  id: string
  search(keyword: string): Promise<MusicInfo[]>
  getMusicUrl(music: MusicInfo, quality: string): Promise<string>
  getLyric(music: MusicInfo): Promise<LyricInfo>
}
export class LocalSource implements SourceAdapter { ... }  // MVP 内置
// 二期：OnlineSourceRegistry.register(new WySource()) —— 按原 musicSdk/wy 移植
```

## 四、分期计划

| 阶段 | 内容 | 状态 |
|---|---|---|
| MVP（本次） | 播放内核/媒体会话/本地导入/歌单管理/歌词/设置持久化/UI | 本文档实现 |
| 二期 | 在线音源（wy/kg/kw 逐个移植 musicSdk，http + cryptoFramework 签名） | 预留接口 |
| 三期 | 自定义源脚本（JSVM）、PC 同步（sync 插件移植）、桌面歌词（悬浮窗） | 架构预留 |
| 四期 | 横竖屏双布局对齐原版、主题系统移植（themes.ts 243KB 主题数据）、换源 | — |

## 五、风险与对策

1. **无 DevEco 环境验证**：本会话环境无 DevEco Studio/hvigor，构建需用户侧执行；代码严格对齐 API 12 SDK 规范编写并人工审查。
2. **picker 授权时效**：直接引用 picker 返回的临时 URI 会失效 → 采用"复制进沙箱"策略根治。
3. **媒体封面格式**：mediaMetadata 图片可能为 bmp/png/jpg，统一落盘后在 UI 侧用 Image 展示。
4. **版权/协议**：保留 Apache 2.0 与原项目补充协议；MVP 不内置任何在线音源，规避版权风险。