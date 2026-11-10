# lx-music-mobile 鸿蒙（HarmonyOS NEXT）改造可行性分析

> 分析基准：github.com/lyswhut/lx-music-mobile @ master（v1.8.4, versionCode 76）
> 分析日期：2026-09-01

## 一、项目概况

| 项 | 内容 |
|---|---|
| 项目 | CCMusic（CC音乐）移动版，18k stars 的开源音乐播放器 |
| 技术栈 | React Native 0.73.11 + React 18.2 + Redux（自建 store：Provider/state/action/hook） |
| 现支持平台 | 仅 Android 5+（README 明确声明"没有计划支持 iOS 和 HarmonyOS NEXT"） |
| 协议 | Apache 2.0（允许改造与二次分发，需保留版权声明） |
| 代码规模 | src/ 约 620 个 TS/JS 文件 + Android 原生 Java 模块（包名 cn.ccn.music.mobile） |

### 模块分布

| 模块 | 文件数 | 说明 | 是否含原生代码 |
|---|---|---|---|
| screens/ | 223 | UI 页面（主页/播放详情/搜索/歌单/设置，横竖双布局） | 否（React 组件） |
| utils/ | 124 | 工具库 + **musicSdk 六大音源 SDK（79 文件，纯 JS）** + 原生桥接 | 桥接层薄封装 |
| components/ | 71 | 共享 UI 组件库 | 否 |
| store/ | 47 | 全局状态（player/list/setting/theme 等 16 个领域） | 否 |
| core/ | 54 | 业务核心（播放器状态机/歌词/列表/搜索/初始化） | 否 |
| plugins/ | 27 | 播放器插件、歌词插件、存储、PC 同步客户端 | 否 |
| android/ | ~40 Java 文件 | 原生模块：Cache、Crypto(AES/RSA)、Lyric(桌面歌词)、UserApi(**QuickJS**)、Utils | 是 |
| ios/ | — | 未完成支持 | — |

### 核心原生依赖盘点（package.json，14 个 dependencies）

| 依赖 | 用途 | 鸿蒙生态现状 | 适配难度 |
|---|---|---|---|
| react-native-track-player（作者 fork） | **音频播放内核 + 后台服务 + 通知栏** | 无鸿蒙版，需用 AVPlayer + AVSession 重写 | 高（核心） |
| react-native-navigation (Wix) | 原生导航 | 无鸿蒙版，需改用 react-navigation 或鸿蒙 Navigation | 高 |
| @react-native-async-storage/async-storage | KV 存储 | 官方有 harmonyos 适配版 / 可换 Preferences | 低 |
| @react-native-clipboard/clipboard | 剪贴板 | 有 harmonyos 适配版 | 低 |
| @react-native-community/slider | 滑块 | 有 harmonyos 适配版 | 低 |
| react-native-pager-view | 分页 | 有 harmonyos 适配版 | 低 |
| react-native-fs / react-native-file-system (fork) | 文件系统 | 需用 @ohos.file.fs 重写 | 中 |
| react-native-quick-base64 / quick-md5 | 编解码 | 纯 JS 库可替代（性能换兼容） | 低 |
| react-native-background-timer (fork) | 后台定时器 | 随后台服务在 ArkTS 侧实现 | 中 |
| react-native-local-media-metadata (fork) | 本地歌曲元数据读取 | 需用 @ohos.multimedia.mediaMetadata 重写 | 中 |
| react-native-vector-icons | 图标字体 | 纯 JS + 字体文件，可直接复用 icomoon.ttf | 低 |
| react-native-exception-handler | 全局异常 | 鸿蒙 ErrorManager 可替代 / 可裁剪 | 低 |

### 关键 Android 原生模块（必须重写的部分）

1. **UserApiModule（QuickJS）**：运行用户自定义音源 JS 脚本 —— CCMusic 的核心特性。鸿蒙替代方案：JSVM API（Node-API 内嵌 JS 引擎）或 ArkWeb 离屏执行。
2. **CryptoModule（AES/RSA）**：备份加密。替代：@ohos.security.cryptoFramework。
3. **LyricModule（桌面歌词）**：原生悬浮窗自绘。替代：鸿蒙悬浮窗（window.createWindow + SubWindow）+ ArkUI 自绘。
4. **CacheModule**：缓存清理。替代：@ohos.file.fs 遍历删除。
5. **react-native-track-player fork**：播放/队列/通知栏/线控。替代：AVPlayer + AVSession（AVSessionManager）+ LongRunningTask 保活。

## 二、改造路线分析

### 路线 A：React Native for OpenHarmony（RNOH）移植

**原理**：保留 src/ 全部 JS/TS 业务代码，用华为维护的 react-native-harmony 替换 RN 渲染层，原生模块补写鸿蒙 ArkTS 适配（TurboModule）。

**有利条件**：
- 业务层（core/store/plugins/utils/screens，约 580 文件）理论上零改动或极少改动
- RN 0.73 与 RNOH 支持的 0.72.5 版本差异较小，可降级适配
- 生态已有 async-storage、clipboard、slider、pager-view 等 harmonyos 版三方库

**不利条件**：
- 需引入 RNOH SDK（react_native_openharmony.har + CMake 配置），构建链复杂
- **10+ 个依赖中 4 个核心库无鸿蒙版**（track-player、navigation、file-system、local-media-metadata），须自行编写 ArkTS TurboModule
- 4 个作者私有 fork 库无上游鸿蒙支持，需对照 Android 实现逐个重写
- react-native-navigation（Wix）深度侵入原生导航栈，鸿蒙适配工作量最大，建议改为 react-navigation（纯 JS）→ 波及 navigation/ 目录 12 个文件
- QuickJS 桥接需通过 JSVM 重做
- 总体：**JS 层保留 90%+，原生层 100% 重写**，适合团队长期投入；一次性环境搭建与调试成本高（当前会话环境无 DevEco/hvigor 验证条件）

### 路线 B：ArkTS 原生重写（推荐 MVP 起点）

**原理**：以标准 Stage 模型工程为壳，UI 用 ArkUI 声明式开发，业务逻辑分层移植：
- 播放内核 → AVPlayer + AVSession（后台播放/媒体通知/线控开箱即用）
- 状态管理 → ArkTS @State/@Observed + AppStorage（对应 Redux store）
- 存储 → Preferences（对应 async-storage）+ 关系型数据库（歌单）
- 音源 SDK → 逐平台移植到 ArkTS http（加密逻辑用 cryptoFramework）或预留 userApi 扩展
- 歌词解析 → lrcTools.ts / lrc-file-parser 逻辑直接翻译（纯算法，无平台依赖）

**有利条件**：
- 零外部 SDK 依赖，工程可独立构建，演进路径清晰（后续接 ArkUI-X 或作为完全独立 App）
- 音质/后台保活/媒体控制等音乐 App 核心体验直接使用鸿蒙系统级 API
- 可裁剪范围灵活：本地播放器（最小）→ 在线搜索播放（推荐）→ 全功能（长期）

**不利条件**：
- 620 文件 UI+逻辑无法一次性全量重写（screens 223 文件），需分阶段
- musicSdk 六音源各自含签名加密，逐个移植成本高（建议先接 1~2 源验证架构）

### 路线 C：ArkWeb 混合封装（不推荐）

用 WebView 跑现有 Web 版/本地 Bundle：音乐后台播放、媒体通知、离线能力均受限，体验差，仅适合快速演示，不作为方案。

## 三、结论

**可行。** 两条可行路线：

| 维度 | A：RNOH 移植 | B：ArkTS 重写 |
|---|---|---|
| JS 业务代码复用 | ~90% | 算法层可翻译复用，UI 重写 |
| 原生工作量 | 全部重写（10+ 模块） | 按需实现（系统 API 免写桥接） |
| 构建/调试门槛 | 高（RNOH SDK + 版本对齐） | 中（标准 DevEco 工程） |
| 长期演进 | 受 RNOH 版本节奏约束 | 完全自主 |
| 适用场景 | 追求与 Android 版功能/体验完全对齐 | 快速落地可用版本，逐步补全 |

**建议**：以 **路线 B（ArkTS 原生重写）** 建立可运行的鸿蒙工程基座，先实现核心闭环（本地/在线播放、歌单管理、搜索、歌词、设置、后台播放与媒体控制），架构上对齐原项目分层（core/store/utils），保留 musicSdk 接口形状以便后续逐源移植；若后续需要 100% 功能对齐（自定义源脚本、PC 同步、桌面歌词等），可在基座上评估 RNOH 或继续原生补齐。

## 四、风险与注意事项

1. **版权与协议**：原项目 Apache 2.0 + 补充协议（非商业、24 小时清除版权数据条款），改造版须保留原始许可声明并遵守补充协议。
2. **音源合规**：在线音源接口随时可能失效，且涉及版权敏感性，改造版应默认仅含本地播放能力，在线源作为可配置扩展。
3. **后台播放**：鸿蒙需申请 `ohos.permission.KEEP_BACKGROUND_RUNNING` + `backgroundModes: ["audioPlayback"]`，并用 AVSession 保持媒体会话。
4. **自定义源脚本（userApi）**：JSVM 方案需处理无 DOM/网络环境差异，是全功能对齐的最大技术风险点，建议二期实现。