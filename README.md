# 华为系列 跨端框架 [Ark官网](https://developer.harmonyos.com/cn/develop/)

[开发工具](https://developer.harmonyos.com/cn/develop/deveco-studio/#download)
[语法文档](https://developer.harmonyos.com/cn/develop/arkts/)
[UI组件](https://developer.harmonyos.com/cn/develop/arkUI/)

# CC音乐 HarmonyOS 版（lx-music-hm）
基于开源项目 [lyswhut/lx-music-mobile](https://github.com/lyswhut/lx-music-mobile)（v1.8.4）的鸿蒙（HarmonyOS NEXT）改造版。

> 上游协议：Apache License 2.0（含补充协议），本工程遵循原协议。

## 功能

- 搜索后自动收起输入法键盘，避免键盘遮挡搜索结果（点「搜索」/回车/采纳建议/点词条均生效）；
- 搜索源用**下拉选择**，默认「**聚合**」：并行查所有内置音源并按「歌名+歌手」归一化去重，
  同一首歌保留音质更高的那条（flac24bit > flac > 320k > 128k）；
- 搜索框**在线联想词**：输入时向当前源取在线联想（对齐 lx-music-desktop 的 tipSearch，
  酷我/酷狗/网易/QQ 支持，咪咕接口已下线自动降级；聚合模式取各源联想的合并），
  300ms 防抖、最多 8 条，支持 ↑↓ 选择、点击采纳、回车确认，无匹配时给空状态提示；
  **切换搜索源不会触发联想**（联想只在输入时出现，切换源只收起当前联想）；
- 按歌曲检索歌词：播放详情页可跨音源检索歌词（本地导入的歌用歌名+歌手反查同名曲），
  切歌自动重新检索，检索不到时给明确占位提示；
- 搜索结果支持「播放全部」（音源切换行最右侧，把整个搜索结果作为队列播放）；
  点单曲时播放队列**只放这一首**，不把整个搜索结果塞进队列；
- 本地音乐导入（文件选择器多选 mp3/flac/wav/m4a/aac/ogg/ape/wma，自动复制进应用沙箱；
  AVMetadataExtractor 解析标题/歌手/专辑/时长/封面，失败回退文件名解析）
- 播放列表页（入口 Tab「播放列表」）：两个分区 —— 本地列表 / 喜欢列表，选中项高亮、点击切换内容区；
  本地列表内置黑色「导入音乐」按钮，本地导入与收藏分别存于「本地音乐」「喜欢的音乐」两个内置列表
- 歌曲信息带**音质与来源徽标**（对齐 lx-music 的 OnlineList/ListItem）：
  音质分无损24/无损/高品/128k 四档并用颜色区分（无色底，纯文字小标签），
  来源在聚合搜索时显示（单源搜索整页同源不显示），歌单列表始终显示；
- 收藏状态区分：已收藏显示红色实心 ♥，未收藏显示灰色空心 ♡（搜索结果与歌单列表一致）；
- 健壮性：用户触发的异步操作（收藏/播放/导入/删除/换源/清缓存/清数据等）失败均提示并留日志，
  不会静默失败；音源请求日志中的 key/token 等凭据参数自动脱敏；
- 多歌单管理（搜索页「加入歌单」可新建/选择歌单；歌单数据与桌面版 PC 同步）
- 音源检索顺序为固定顺序（设置页不提供调整入口）
- 播放列表管理（点击播放、左滑删除）
- 播放内核（AVPlayer）：进度/时长、列表循环 / 列表随机 / 单曲循环、上一曲/下一曲、
  拖动进度、**音量调节（0–100 + 静音）**、播放队列管理（移除/点播/**重排/清空**）、**另存队列为歌单**、
  随机模式下的播放历史（"上一首"回到上一首实际播过的歌）、失败重试
- 模块分层：`app/`（编排层 PlayerFacade）→ `core/` `player/` `lyric/` `api/` `sync/`（能力层）
  → `model/` `persistence/` `utils/`（数据层），无循环引用
- 在线播放音质：128k / 320k / FLAC / Hi-Res，按曲目可用质量自动降级
- 收藏（喜欢的音乐）：搜索结果与播放详情页一键收藏，默认列表即收藏夹
- 后台播放 + 媒体通知（AVSession + 长时任务 AUDIO_PLAYBACK，支持耳机/通知栏线控，本地封面展示）
- 歌词（.lrc 解析、滚动高亮、手动导入歌词文件绑定歌曲）
- 悬浮歌词（应用内可拖动歌词条，播放详情页/设置页开关；跨应用悬浮窗需系统权限，暂不支持）
- 恢复上次播放（快照记录歌单/曲目/进度，受"恢复播放进度"开关控制）
- 外观主题：跟随系统 / 浅色 / 深色（dark 限定词资源全套适配）
- 换源播放：播放详情页选源搜索同名歌曲，候选列表确认后替换当前播放（队列其余不变）
- 返回键处理（先收起播放详情；可选退出二次确认）
- 设置页按上游 lx-music-mobile 的分区组织：基本设置 / 播放设置 / 歌词设置 / 列表设置 /
  搜索设置 / 数据同步 / 备份与恢复 / 其它 / 关于；
  点击标题栏展开左侧抽屉，纵向列出全部分区（当前项高亮），抽屉收起后内容区正常交互
- 深浅色自适应（跟随系统）
- 在线音源：酷我 kw / 网易云 wy / 酷狗 kg / QQ tx / 咪咕 mg（搜索、多质量直链、歌词），搜索页"加入歌单"可选目标歌单
- 自定义音源脚本（三期）：导入洛雪生态 .js 音源脚本（ArkWeb 沙箱 + lx v2 契约），
  播放链接/歌词自定义源优先、内置源兜底；设置页可导入/更新/移除/开关
- PC 数据同步（三期）：连接 lx-music 桌面版同步服务（协议 v4），同步歌单；
  支持连接码认证与密钥复连

## 构建

1. 安装 DevEco Studio 5.0+（HarmonyOS NEXT SDK，API 12+）
2. 打开本工程根目录，等待 hvigor 同步
3. 连接真机/模拟器，点击 Run

### 部署到模拟器（推荐用脚本）

```bash
tools/deploy-emulator.sh            # 体检 hdc 通道 + 安装 + 启动
tools/deploy-emulator.sh --build    # 先构建再安装
tools/deploy-emulator.sh --health   # 只体检通道
```

脚本会在安装前分别体检 hdc 的**命令通道**与**文件传输通道**：
若出现「命令通、文件通道挂死」（DevEco 报「推送超时」的真正成因），会自动重启 hdc server 修复。
详见 `docs/troubleshoot-emulator.md`。

命令行构建（已验证通过，详见 `docs/build-fix-report.md`）：

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p product=default assembleHap --parallel --incremental --no-daemon
```

> 注：本 SDK 要求资源引用使用三段式 `$r('app.media.xxx')` / `$r('app.color.xxx')` 格式。

## 使用

1. 首页点击右上角「导入音乐」，从手机选择音频文件（可多选，自动读取内嵌元数据与封面）
2. 点击列表中的歌曲开始播放；底部迷你条可展开播放详情页
3. 歌单栏可新建/切换歌单，长按歌单名可重命名/清空/删除
4. 播放详情页右上角：悬浮歌词开关、导入与音频同名的 `.lrc` 歌词
5. 搜索页支持酷我/网易云/酷狗在线搜索，「加入歌单」时选择目标歌单（可现场新建）

## 工程结构

```
entry/src/main/ets/
├── app/                             # 编排层：播放域唯一入口（PlayerFacade），装配依赖注入
├── entryability/EntryAbility.ets   # 启动初始化序列（存储→歌单→设置→编排层→悬浮窗→同步→音源引擎）
├── pages/                          # Index（主页容器+返回键）/ MyListView（多歌单）/ SearchView / SettingView / PlayDetail / FloatLyricPage
├── components/                     # PlayerBar（迷你条）/ MusicListItem / LyricView / FloatLyricBar（悬浮歌词）/ SourceSandboxHost（音源沙箱宿主）
├── core/queue/                     # PlayQueue（播放队列纯逻辑）/ PlayModePolicy（上下曲策略）
├── core/volume/                    # VolumeController（音量状态与持久化）/ SystemVolume（系统媒体音量只读与监听）
├── core/source/                    # SourceResolver（统一音源入口）/ SourceEngine（自定义源沙箱）/ SourceStore（音源持久化）/ LxHttp（沙箱网络代理）/ LxMetadata / LxTypes
├── core/music/                     # LxCrypto（沙箱侧加密依赖）
├── player/                         # PlayerKernel（AVPlayer 状态机+恢复进度）/ MediaSessionController（AVSession+后台）
├── model/                          # MusicInfo（对齐上游 LX.Music.MusicInfo）/ SongList / AppSettings
├── store/                          # ListStore（设置与歌单状态）/ PlayerStore（播放快照持久化）
├── persistence/                    # PreferencesUtil / ListPersistence（多歌单）/ SettingPersistence
├── lyric/                          # LyricParser（移植上游 lrcTools 正则）/ LyricManager / FloatLyricWindow（桌面悬浮窗）
├── sync/                           # SyncManager（PC 同步，协议 v4）/ SyncAuth / SyncCrypto / SyncMsg / SyncListData
├── api/                            # MusicSource（音源抽象）+ SourceBootstrap（注册）+ kw/wy/kg/tx/mg 内置在线源
└── utils/                          # FileScanner（导入）/ MetadataReader（AVMetadataExtractor）/ CryptoUtil / HttpUtil / FormatUtil / ThemeController
```

> 自定义源脚本引擎：三方应用无 ArkTS 侧 jsvm API，引擎采用隐藏 ArkWeb 沙箱
> （`components/SourceSandboxHost.ets` + `resources/rawfile/lx_host.html`，
> 引擎代码 `lx_utils.js` / `lx_preload.js` 由 ArkTS 侧读出后注入），
> 对外契约对齐洛雪 v2（lx.on/send/request/utils），详见 `docs/user-api-report.md`。

## 与上游的架构映射

详见 `docs/refactor-plan.md`；可行性分析见 `docs/feasibility-analysis.md`；实施报告见 `docs/refactor-report.md`；工程收敛与在线音源见 `docs/convergence-report.md`；功能完善批次见 `docs/enhance-report.md`。

## 后续路线

- 四期剩余：横竖屏双布局
- PC 同步目前仅同步歌单，待扩展更多数据类型