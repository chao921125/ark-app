# 功能完善批次报告（多歌单 / 元数据 / 悬浮歌词 / 恢复进度 / 返回键）

> 日期：2026-09-04
> 工程：/Users/huangchao/Work/temp/lxmusic-hm
> 前置：`convergence-report.md`（工程修复 + 在线音源 kw/wy/kg）

## 一、遗留项收口

收敛报告中的「待手动操作」png 图标已复制完成：
`AppScope/.../{foreground,background}.png`、`entry/.../{foreground,background,startIcon}.png`。

## 二、多歌单管理（四期）

### 新增/修改

| 文件 | 内容 |
|------|------|
| `pages/MyListView.ets`（重写） | 歌单栏（横向 chips，显示曲目数，长按管理）；新建/重命名输入弹层；管理弹层（重命名/清空/删除，默认列表不可删除）；导入音乐加入当前选中歌单 |
| `pages/SearchView.ets` | 「加入歌单」改为弹层选择目标歌单（列表 + 每单曲目数），弹层内可「新建歌单并加入」；重复添加按目标歌单去重提示 |
| `persistence/ListPersistence.ets` | 新增 `renameList(id, name)`（addList/removeList/clearList 此前已有） |

### 行为说明

- 播放快照按 `listId` 记录，切换歌单播放互不干扰（复用既有 `PlayerStore.playFromList`）。
- 删除/清空均有二次确认；删除歌单后自动回落到第一个歌单。
- 弹层采用页面内覆盖层实现（Stack + 遮罩），不依赖 CustomDialogController，规避其刷新时序问题。

## 三、本地元数据解析（四期）

### 新增/修改

| 文件 | 内容 |
|------|------|
| `utils/MetadataReader.ets`（新增） | `AVMetadataExtractor`（API 12）解析 title/artist/album/duration；`fetchAlbumCover()` → ImagePacker 落盘 `<音频名>_cover.jpg`；全流程防御式（任何失败降级为空字段） |
| `utils/FileScanner.ets` | 导入时调用 MetadataReader：标题/歌手/专辑/时长优先取元数据，失败回退文件名解析与按码率估算；封面路径写入 `meta.picUrl` |

### 收益

- 歌曲名/歌手/专辑/时长不再依赖文件名与估算。
- `meta.picUrl` 有值后，媒体通知（AVSession `picFd`）可展示本地音乐封面。

## 四、悬浮歌词（三期，应用内实现）

### 新增/修改

| 文件 | 内容 |
|------|------|
| `components/FloatLyricBar.ets`（新增） | 可拖动歌词条：PanGesture 拖动定位、进度同步高亮当前行（复用 LyricManager 缓存）、点击展开播放详情、可关闭 |
| `pages/Index.ets` | Stack 顶层挂载 FloatLyricBar（覆盖内容区与播放详情之上） |
| `pages/PlayDetail.ets` | 顶栏新增悬浮歌词开关图标（新增 `ic_float.svg`，开启态主题色高亮） |
| `pages/SettingView.ets` | 「歌词」分区新增悬浮歌词 Toggle |
| `model/AppSettings.ets` + `SettingPersistence.ets` + `store/ListStore.ets` | 新增 `showFloatLyric` 设置项（默认关），`ListStore.setShowFloatLyric` 持久化开关 |

### 已知限制

跨应用悬浮窗需要 `ohos.permission.SYSTEM_FLOAT_WINDOW`（system_basic 级，三方应用不可得），
故实现为应用内悬浮层；跨应用桌面歌词需系统级签名或特殊白名单，暂不支持。

## 五、恢复上次播放进度（补全既有设置项）

### 修改

| 文件 | 内容 |
|------|------|
| `player/PlayerKernel.ets` | 新增 `pendingSeekSec`：`setListWithoutPlay(musics, idx, positionSec)` 记录恢复位置，曲目 prepared+play 后 `applyPendingSeek()` 一次性生效（含 maxTime 钳制）；`setList`（新播放）清零 |
| `store/PlayerStore.ets` | 快照增加 `position`（旧快照缺失按 0 处理）；`saveSnapshotPosition()` 取内核当前曲目与进度；`restore()` 按 `restorePlayProgress` 开关决定是否带位置恢复 |
| `player/MediaSessionController.ets` | `onTrackChanged`（切歌）与 `onStatusChanged('paused')`（暂停）时保存快照 |

## 六、返回键处理

| 文件 | 内容 |
|------|------|
| `pages/Index.ets` | `onBackPress`：播放详情展开时先收起；「退出确认」设置开启时弹二次确认（确认后 `terminateSelf`）；否则走系统默认 |

## 七、验证状态与限制

1. 本机无 DevEco Studio/hvigor，未做编译验证；全部改动基于 API 12 SDK 规范人工审查。
2. `AVMetadataExtractor.fetchAlbumCover()` 个别封装格式（如部分 ape/wma）可能无封面/无元数据，均降级不报错。
3. 恢复进度依赖暂停/切歌时快照；进程被系统直接杀掉时进度可能回退到上一次暂停点。
4. 浮歌词拖动边界按 `display` 实际屏幕尺寸计算（px→vp 换算），歌词条近全宽故横向余量小、以纵向拖动为主。
