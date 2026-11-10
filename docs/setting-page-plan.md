# 设置页方案 — 对齐上游 lx-music-mobile

> 上游依据：`https://github.com/lyswhut/lx-music-mobile`（master 分支）
> 一手来源：`src/screens/Home/Views/Setting/`（10 个分区 / 78 个设置项文件）、
> `src/config/defaultSetting.ts`（全部设置键与默认值）、`src/lang/zh-cn.json`（中文文案）。
>
> 本文先**罗列需要展示的设置项**，再**确定 UI 展示方式**，最后给出实施步骤。

---

## 一、上游设置项清单（完整罗列）

上游分区由 `SETTING_SCREENS` 定义，共 10 个：

`basic` `player` `lyric_desktop` `search` `list` `sync` `backup` `other` `version` `about`

### 1. basic 基本设置（17 项）

| 上游设置键 | 上游文案 | 说明 |
|---|---|---|
| common.isStartupAutoPlay | 启动后自动播放音乐 | |
| common.isStartupPushPlayDetailScreen | 启动后打开播放详情页 | |
| common.isShowBackBtn | 显示返回桌面按钮 | |
| common.isShowExitBtn | 显示退出应用按钮 | |
| common.isAutoHidePlayBar | 弹出键盘时自动隐藏播放栏 | |
| common.isHomePageScroll | 启用竖屏首页横向滚动 | |
| common.isAllowProgressBarSeek | 允许通过底栏进度条调整播放进度 | |
| common.useSystemFileSelector | 使用系统文件选择器 | |
| common.alwaysKeepStatusbarHeight | 总是保留状态栏高度 | |
| common.isAutoTheme / theme.id | 跟随系统亮暗模式 / 主题颜色 | |
| common.drawerLayoutPosition | 导航、收藏列表弹出方向 | |
| common.langId | 语言 | |
| common.fontSize | 字体大小设置（重启后生效） | |
| common.shareType | 分享方式 | |
| common.apiSource | 选择自定义源 | |
| common.sourceNameType | 歌曲来源名称类型（别名/原名） | |
| — | 自定义源管理（UserApiEditModal） | 导入/导出/在线导入脚本 |

### 2. player 播放设置（12 项）

| 上游设置键 | 上游文案 |
|---|---|
| player.isSavePlayTime | 记住播放进度 |
| player.isAutoCleanPlayedList | 自动清空已播放列表 |
| player.isHandleAudioFocus | 其他应用播放声音时，自动暂停播放 |
| player.isEnableAudioOffload | 启用音频卸载 |
| player.isShowBluetoothLyric | 显示蓝牙歌词 |
| player.isShowBluetoothFullLyric | 显示完整蓝牙歌词 |
| player.isShowNotificationImage | 在通知栏显示歌曲专辑封面图片 |
| player.isShowLyricTranslation | 显示歌词翻译 |
| player.isShowLyricRoma | 显示歌词罗马音 |
| player.isS2T | 将播放的中文歌词转换为繁体 |
| player.cacheSize | 最大缓存大小（MiB） |
| player.playQuality / togglePlayMethod / volume / playbackRate | 优先音质 / 播放模式 / 音量 / 播放速度 |

### 3. lyric_desktop 桌面歌词（11 项）

显示歌词 / 锁定歌词 / 显示歌词切换动画 / 使用单行歌词 / 歌词主题色 /
歌词字体大小 / 窗口百分比宽度 / 最大行数 / 歌词字体透明度 / 歌词水平对齐 / 歌词垂直对齐

### 4. list 列表设置（4 项）

| 上游设置键 | 上游文案 |
|---|---|
| list.isClickPlayList | 点击列表里的歌曲时自动切换到当前列表播放 |
| list.isShowAlbumName | 显示歌曲专辑名 |
| list.isShowInterval | 显示歌曲时长 |
| list.addMusicLocationType | 添加歌曲到列表时的位置（顶部/底部） |

### 5. search 搜索设置（2 项）

| 上游设置键 | 上游文案 |
|---|---|
| search.isShowHotSearch | 显示热门搜索 |
| search.isShowHistorySearch | 显示历史搜索记录 |

### 6. sync 数据同步（2 项）

| 上游设置键 | 上游文案 |
|---|---|
| sync.enable | 启用同步 |
| — | 同步服务地址 / 端口 / 连接码 / 连接历史 / 当前状态 |

### 7. backup 备份与恢复

所有数据（列表+设置）导出/导入、列表数据导出/导入、设置导出/导入

### 8. other 其他（5 项）

资源缓存管理（歌曲/图片缓存）、其他缓存管理（歌词/歌曲 URL/换源歌曲）、
「不喜欢的歌曲」规则、错误日志查看、自定义源日志

### 9. version 软件更新 / 10. about 关于 LX Music

版本号与更新、开源协议、鸣谢等

---

## 二、本项目能力对照（哪些做、哪些不做）

> 判定依据：本项目当前代码里**已存在**的能力直接暴露；需要新写的标 🔨；
> 依赖上游特有基础设施（桌面歌词窗口样式、跨端同步协议细节、更新服务）的标 ➖ 不做。

### 基本设置

| 设置项 | 状态 | 说明 |
|---|---|---|
| 主题（跟随系统/浅色/深色） | ✅ 已有 | `themeMode` |
| 启动后自动播放音乐 | 🔨 | 启动恢复进度后自动起播 |
| 自定义源管理（导入/激活/移除） | ✅ 已有 | 从当前页搬到本分区 |
| 从 URL 导入音源脚本 | ✅ 已有 | |
| 音源优先级排序 | ✅ 已有 | 本项目特色，上游没有 |
| 显示返回桌面/退出应用按钮 | ➖ | 本项目底栏固定三项 |
| 弹出键盘时自动隐藏播放栏 | ➖ | |
| 竖屏首页横向滚动 | ➖ | |
| 底栏进度条可拖动 | ➖ | 本项目无底栏进度条 |
| 系统文件选择器 / 状态栏高度 / 弹出方向 / 语言 / 全局字体大小 / 分享方式 / 歌曲来源名称 | ➖ | 无对应设施 |

### 播放设置

| 设置项 | 状态 | 说明 |
|---|---|---|
| 播放模式（循环/随机/单曲） | ✅ 已有 | `playMode` |
| 优先播放的音质 | ✅ 已有 | `playQuality` |
| 音量 | ✅ 已有 | 本项目已实现 `VolumeController`，此前未在设置页暴露 |
| 记住播放进度 | ✅ 已有 | `restorePlayProgress` |
| 通知栏显示专辑封面 | 🔨 | 已有 `mediaImage` 能力，加开关 |
| 其他应用播放时自动暂停 | 🔨 | `AVPlayer.audioInterruptMode`（`SHARE_MODE`/`INDEPENDENT_MODE`） |
| 自动清空已播放列表 | 🔨 | 随机模式下清空历史栈 |
| 音频卸载 / 蓝牙歌词 / 歌词翻译 / 罗马音 / 繁简转换 / 缓存上限 / 播放速度 | ➖ | 依赖上游音频栈与歌词增强能力 |

### 歌词设置（上游桌面歌词 → 本项目应用内+悬浮歌词）

| 设置项 | 状态 | 说明 |
|---|---|---|
| 显示悬浮歌词 | ✅ 已有 | `showFloatLyric`（真悬浮窗优先，失败回落应用内条） |
| 歌词字号 | ✅ 已有 | `lyricFontSize` |
| 歌词行间距 | ✅ 已有 | `lyricLineGap` |
| 桌面歌词主题色/透明度/位置/单行/最大行数 | ➖ | 本项目悬浮窗未做样式定制 |

### 列表设置

| 设置项 | 状态 | 说明 |
|---|---|---|
| 显示歌曲时长 | 🔨 | `MusicListItem` 已显示，加开关 |
| 显示歌曲专辑名 | 🔨 | `MusicListItem` 加专辑名 |
| 添加歌曲到列表时的位置 | 🔨 | `ListPersistence.addMusic` 加位置参数 |
| 点击列表歌曲时自动切到当前列表播放 | 🔨 | |

### 搜索设置

| 设置项 | 状态 | 说明 |
|---|---|---|
| 显示历史搜索记录 | 🔨 | 需记录搜索历史 |
| 显示热门搜索 | 🔨 | 需内置热门词表 |

### 数据同步

| 设置项 | 状态 | 说明 |
|---|---|---|
| 启用同步 / 服务地址 / 连接码 / 连接历史 / 状态 | ✅ 已有 | **但当前被 `if (false)` 藏在设置页里**，本轮恢复到独立分区 |

### 备份与恢复

| 设置项 | 状态 | 说明 |
|---|---|---|
| 导出/导入 设置数据 | 🔨 | `DocumentViewPicker.save()` |
| 导出/导入 歌单数据 | 🔨 | `DocumentViewPicker.select()` |

### 其他

| 设置项 | 状态 | 说明 |
|---|---|---|
| 清除数据 | ✅ 已有 | |
| 缓存管理 | 🔨 | 先做歌词/脚本缓存的统计与清理 |
| 错误日志查看 | 🔨 | 导出日志文件 |

### 关于

| 设置项 | 状态 | 说明 |
|---|---|---|
| 版本号 / 开源协议 | 🔨 | |

---

## 三、UI 展示方案

### 3.1 整体结构（对齐上游 `Vertical/Main.tsx` + `Vertical/NavList.tsx`）

```
┌──────────────────────────────────────────┐
│  设置                                      │  ← 22px 粗体标题（保留现有）
├──────────────────────────────────────────┤
│  基本设置  播放设置  歌词  列表  搜索  …    │  ← 横向滚动 Tab 栏（上游 NavList）
│  ▔▔▔▔▔▔                                  │     选中项：theme_primary 底 + 白字
├──────────────────────────────────────────┤
│  │ 播放设置                                │  ← Section 标题：左侧 5px 主题色竖条
│  ┌────────────────────────────────────┐  │     16px + 12px 左距 + 10px 下距
│  │ 播放模式              列表循环    › │  │
│  │ ──────────────────────────────────  │  │
│  │ 优先音质              标准 128k   › │  │  ← 卡片：bg_card 底 / 12px 圆角
│  │ ──────────────────────────────────  │  │     项之间 1px divider
│  │ 音量                    ●────  80 │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

**分区导航：左侧抽屉（纵向排列）**

上游有横竖两套布局：`Horizontal/NavList.tsx` 是顶部横向 Tab，
`Vertical/Header.tsx` + `Vertical/NavList.tsx` 则是**抽屉式**——
顶部是一行可点击的 Header（左侧 chevron 图标 + 当前分区名），点击展开纵向导航。

本项目采用**抽屉式**：

```
┌──────────────────────────────┐
│ 设置                播放设置 › │  ← 整行可点击，展开抽屉
├──────────────────────────────┤
│                              │
│  （内容区，被遮罩压暗）        │
│                              │
└──────────────────────────────┘

抽屉（从左侧滑出，宽 70% 屏宽）：
┌────────────────┐
│ 设置            │
│ ──────────────  │
│ ● 基本设置      │ ← 主题色文字 + 左侧 3px 指示条 + 浅色底
│   播放设置      │
│   歌词设置      │
│   列表设置      │
│   搜索设置      │
│   数据同步      │
│   备份与恢复    │
│   其它          │
│   关于          │
└────────────────┘
```

- 标题行右侧显示**当前分区名 + `›`**，既是抽屉入口，也是当前位置指示
- 点击抽屉项 → 切换分区并收起抽屉；点击遮罩 → 收起抽屉
- 抽屉收起态用 `HitTestMode.None`，避免不可见的抽屉拦截内容区触摸

**为什么用抽屉而不是横向 Tab**：抽屉纵向排列能一屏看完所有分区（9 个），
横向 Tab 需要滑动才能看到后面的分区；且与上游竖屏布局一致。

**平台边界**：本工程 SDK 未提供 `bindDrawer` / `bindSideSheet`，
`Panel` 组件是底部半模态而非侧边抽屉，因此抽屉用
`Stack` + `translate` 动画自绘（`Stack` 需设 `alignContent(Alignment.TopStart)`，
否则抽屉会因默认居中对齐跑到屏幕中间）。

### 3.2 行控件规范（5 种，复用现有样式）

| 控件 | 视觉 | 用于 |
|---|---|---|
| 开关行 | 标题 15px + 副说明 11px + 右侧 `Toggle` | 布尔项 |
| 单选行 | 标题 15px + 右侧当前值 13px + `›` | 播放模式 / 音质 / 主题 / 添加位置 |
| 滑块行 | 标题 15px + 右侧当前值 13px + 下方 `Slider` | 音量 / 歌词字号 / 行间距 |
| 输入行 | 标签 14px + 下方 `TextInput` | 同步地址 / 连接码 |
| 操作行 | 标题 15px + 副说明 11px + 右侧状态或 `›` | 导出/导入 / 清理 / 关于 |

选项多于 3 个时（如音质 4 项）用**底部弹层单选**，而非直接铺开成列表行 —— 与播放详情页现有的
「保存为歌单」弹层交互一致。

### 3.2.1 抽屉与横向 Tab 的取舍

两者都可行，本轮按用户要求改为抽屉。改动只影响 `pages/SettingView.ets`，
9 个分区文件无需任何改动。

### 3.3 通用控件抽取

`components/setting/SettingWidgets.ets` 导出**全局 @Builder 函数**（不在 struct 内，
可被任意分区的 build 直接调用）：

- `SettingSectionTitle(title: string)` — 分组标题
- `SettingSwitchRow(title, desc, isOn, onChange)`
- `SettingRadioRow(title, value, onClick)`
- `SettingSliderRow(title, value, min, max, step, onChange)`
- `SettingInputRow(label, text, placeholder, onChange)`
- `SettingActionRow(title, desc, actionText, onClick)`

> 用全局 @Builder 而非 @BuilderParam 组件：避免 @BuilderParam 跨文件传参的约束，
> 且各分区文件可自由组合，无需层层包一层组件。

### 3.4 文件结构

```
entry/src/main/ets/
├── components/setting/SettingWidgets.ets   【新增】通用行控件
├── pages/setting/
│   ├── BasicSection.ets      【新增】基本设置
│   ├── PlayerSection.ets     【新增】播放设置
│   ├── LyricSection.ets      【新增】歌词设置
│   ├── ListSection.ets       【新增】列表设置
│   ├── SearchSection.ets     【新增】搜索设置
│   ├── SyncSection.ets       【新增】数据同步
│   ├── BackupSection.ets     【新增】备份与恢复
│   ├── OtherSection.ets      【新增】其他
│   └── AboutSection.ets      【新增】关于
└── pages/SettingView.ets     【重写】Tab 编排 + 内容区
```

> 现有 `SettingView.ets` 已 1028 行且把 8 类设置平铺在一页；
> 按上游的分区思路拆分后，每个文件职责单一。

---

## 四、实施步骤

1. **模型**：`AppSettings` 增加 10 个设置项 + 默认值 + 校验函数；`SettingPersistence` 兼容旧数据（缺字段用默认值）
2. **控件**：`components/setting/SettingWidgets.ets`
3. **分区**：9 个分区文件
4. **编排**：`SettingView.ets` 重写为 Tab 编排，把现有「自定义音源」「音源优先级」搬进基本设置、
   把被隐藏的「PC 同步」搬进数据同步
5. **打通**：新增设置项接到实际功能（列表项显示、添加位置、搜索历史/热门、音频焦点、通知栏封面、启动播放、备份）
6. **验证**：编译 + 模拟器实跑各分区

---

## 五、兼容性

| 项 | 说明 |
|---|---|
| 旧设置数据 | 新增字段缺失时回落默认值，`SettingPersistence` 读取时做合并 |
| 现有功能 | 自定义音源管理、音源优先级、PC 同步、清除数据全部保留，只是换了位置 |
| 上游差异 | 本项目的「音源优先级」是上游没有的，保留并放在基本设置 |

---

## 六、实施结果（2026-10-26）

### 新增文件

| 文件 | 内容 |
|---|---|
| `components/setting/SettingWidgets.ets` | 通用行控件（全局 @Builder）：分组标题/开关行/单选行/滑块行/输入行/操作行/说明文字 |
| `components/setting/SettingOptionSheet.ets` | 单选弹层（播放模式、音质、主题、添加位置共用） |
| `pages/setting/BasicSection.ets` | 基本设置（主题、启动自动播放、自定义音源管理、音源优先级） |
| `pages/setting/PlayerSection.ets` | 播放设置（模式/音质/音量/恢复进度/音频焦点/通知栏封面/自动清空已播放） |
| `pages/setting/LyricSection.ets` | 歌词设置（悬浮歌词、字号、行间距） |
| `pages/setting/ListSection.ets` | 列表设置（时长、专辑名、添加位置） |
| `pages/setting/SearchSection.ets` | 搜索设置（历史搜索、热门搜索） |
| `pages/setting/SyncSection.ets` | 数据同步（**从 `if (false)` 隐藏区恢复**） |
| `pages/setting/BackupSection.ets` | 备份与恢复（设置/歌单的导入导出） |
| `pages/setting/OtherSection.ets` | 其它（缓存管理、清除全部数据） |
| `pages/setting/AboutSection.ets` | 关于 |
| `persistence/SearchHistory.ets` | 搜索历史持久化（最多 10 条） |

### 修改文件

| 文件 | 改动 |
|---|---|
| `pages/SettingView.ets` | **重写**（1028 行 → 约 100 行）：从平铺 8 类设置改为分区 Tab 编排 |
| `model/AppSettings.ets` | 新增 10 个设置项 + `cloneSettings` / `clampVolume` |
| `persistence/SettingPersistence.ets` | 逐字段合并（新增字段缺失回落默认值，旧设置数据兼容） |
| `core/volume/VolumeController.ets` | 持久化职责上移至 AppSettings，本模块只留运行时状态 |
| `app/PlayerFacade.ets` | 音量落盘改 600ms 防抖；新增把设置推给内核/媒体会话的通道；启动自动播放 |
| `player/PlayerKernel.ets` | 新增 `setAudioFocusEnabled` / `setAutoCleanPlayedList` / `applyInterruptMode` |
| `player/MediaSessionController.ets` | 新增通知栏封面开关 |
| `components/MusicListItem.ets` | 新增 `showInterval` / `showAlbumName` 两个 prop |
| `persistence/ListPersistence.ets` | `addMusic` 支持插入位置（top/bottom） |
| `pages/SearchView.ets` | 热门/历史搜索、专辑名显示、加入歌单位置 |
| `pages/MyListView.ets` | 列表显示开关、导入位置 |
| `utils/FileScanner.ets` | 新增 `writeTextToUri` / `pickSaveTarget` / `pickJsonFile` |

### 实测验证（模拟器）

- 9 个分区 Tab 全部可切换、内容与设计一致、视觉与项目原有风格统一
- 「显示悬浮歌词」开关 → 首页出现悬浮歌词条（端到端打通）
- 缓存统计可用（歌词 0 个 · 封面 1 个 · 46 KB）
- 编译 BUILD SUCCESSFUL；验证台 87 项全过；循环依赖 0、分层违规 0

### 平台边界（本轮明确不做的）

- 上游 `version` 分区依赖其更新服务 → 不做
- 桌面歌词的主题色/透明度/位置/单行 → 本项目悬浮窗未开放样式定制
- 音频卸载/蓝牙歌词/歌词翻译/罗马音/繁简转换/缓存上限 → 依赖上游音频栈与歌词增强能力
- 「不喜欢的歌曲」规则、错误日志查看 → 本项目未实现对应能力
