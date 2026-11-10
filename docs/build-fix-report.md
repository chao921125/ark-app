# 构建修复报告（2026-09-06，DevEco Studio 真机 SDK 首次编译）

> 本机 DevEco Studio SDK 对工程做首次真实编译：244 errors / 89 warnings → **BUILD SUCCESSFUL（0 error）**，
> 产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`。
> 全部修复均已对照本机 SDK d.ts（`DevEco.app/Contents/sdk/default/openharmony/ets/`）核实。

## 命令行构建方式（无需打开 IDE）

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  --mode module -p product=default assembleHap --parallel --incremental --no-daemon
```

## 修复清单（按根因归类）

### 1. 资源引用格式（占错误大多数）
本 SDK 要求三段式资源引用，两段式全部报 "Invalid resource file parameter (xxx.yyy.zzz)"：
`$r('color.x')` / `$r('media.x')` → `$r('app.color.x')` / `$r('app.media.x')`（全局 144 处）。

### 2. Kit 导入与 API 形态（本 SDK 与旧文档差异）
| 位置 | 修复 |
|---|---|
| MediaSessionController | `avSession` 从 `@kit.AudioKit` → `@kit.AVSessionKit`；`@kit.BackgroundTaskKit` → `@kit.BackgroundTasksKit`（带 s） |
| MediaSessionController | `AVMetadata.picFd` 不存在 → `mediaImage?: PixelMap \| string`（直接传沙箱封面路径）；删除 picFd/fd 管理 |
| MediaSessionController | `PlaybackPosition.currentTime` → `elapsedTime`（必填 + 必填 `updateTime`）；`on('seek')` 回调参数为 `(time: number)`，无 `SeekCommand` 类型 |
| EntryAbility | `AbilityConstantLaunchParam` 不存在 → `AbilityConstant.LaunchParam` |
| promptAction | `DialogSuccessResult` 不存在 → `ShowDialogSuccessResponse`（Index/MyListView/SettingView） |
| WyCrypto | `createSymmetricCipher` → `createCipher`；`SymmetricCipher` → `Cipher`；Record 字面量键必须加引号 `'params': ...` |
| MetadataReader | `image.PackingOptions` → `image.PackingOption`；`ImagePacker.pack`（缓冲区）不存在 → `packToFile(pixelMap, fd, options)` 直写文件 fd |
| FileScanner | `fs.readTextSync` 无 fd 重载 → `fs.readSync(fd, ArrayBuffer)` + TextDecoder；`fs.writeTextSync` 不存在 → `openSync + writeSync + closeSync`（UserApiManager 同） |

### 3. ArkTS 严格模式
| 规则 | 修复 |
|---|---|
| `arkts-limited-throw`（throw 只接受 Error 子类；接口形态 BusinessError 不行） | 新增 `NormalizedError extends Error { code }`（HttpUtil 导出）；HttpUtil/5 个 Api 文件的 `makeBizError`、5 个 Source 文件与 PlayerKernel 的字面量 throw、FileScanner 的 `throw e`、UserApiManager 的 `makeError` 全部改为抛 `NormalizedError`（消费端 `e as BusinessError` 结构兼容不受影响） |
| `arkts-no-untyped-obj-literals` | WyCrypto 的 Record 字面量键加引号 |
| `arkts-no-standalone-this` | LyricParser 静态方法内 `this.msToLabel` → `LyricParser.msToLabel` |
| 组件保留名冲突 | Index 的 `@State tabIndex` 与 UI 属性 `tabIndex` 冲突 → 更名 `currentTab` |

### 4. UI 组件 API 差异
| 问题 | 修复 |
|---|---|
| `ClickEvent` 无 `stopPropagation` | PlayerBar：整条 onClick 拆到封面/文字区（播放按钮不再冒泡）；MyListView/SearchView 弹层改为 Stack 兄弟层结构（遮罩层 + 卡片层各自命中，无需阻断冒泡） |
| `swipeAction` 只在 `ListItemAttribute`（不在 Row） | 从 MusicListItem 的 Row 移除，迁移到 MyListView 的 `ListItem.swipeAction({ end: () => this.deleteCell(music) })`（新增 deleteCell @Builder） |
| `RadioAttribute` 无 `selectedColor` | 改用 `radioStyle({ checkedBackgroundColor })` |

### 5. 真 Bug：注释提前终止
LyricView 头注释 `PlayDetail/*/Lyric.tsx` 中的 `*/` 把块注释提前终止，导致整文件解析错乱
（表现为 "Cannot find name '$'/Lyric"、"Unterminated template literal"、"is not a module" 等连锁假错误）。

## 遗留（非阻塞）

- 105 条 WARN：`showToast/showDialog/getContext` 已废弃（建议后续迁移 `this.getUIContext()` 系 API）、
  部分 crypto/media API "not supported on all devices" 容量提示。不影响构建与运行。
- HAP 为 unsigned（`entry-default-unsigned.hap`），真机安装需在 DevEco 中配置调试签名或用 IDE Run。

## 追加（2026-09-06 第二轮）：新功能接入 + 兼容修复

用户侧新增（音质/收藏/播放队列/默认列表改名"喜欢的音乐"）接入收尾：

1. **MusicListItem 收藏爱心**：移除 `event.stopPropagation()`（本 SDK ClickEvent 无此方法，
   子组件内建点击优先于父 TapGesture，无需阻断冒泡）。
2. **SearchView 收藏**：结果行新增爱心（toggleLike），ForEach key 加入收藏态与 likeListRev 保证刷新。
3. **PlayDetail 收藏**：顶栏心形开关当前歌曲收藏。
4. **主题模式（四期）落地**：新增 `utils/ThemeController.ets`（ApplicationContext.setColorMode，API 11+，
   已对照本 SDK 核实），`resources/dark` 全套深色资源生效；设置页新增「外观」三选；
   SettingPersistence 增加 themeMode 白名单校验；ListStore.applySettings / EntryAbility 初始化接线。
5. **换源播放（四期）落地**：PlayerKernel 新增 `replaceCurrent()`（替换队列当前位置并续播）；
   PlayDetail 顶栏换源入口（showActionMenu 五源选择 → 同名搜索 → 取首个结果替换播放）。
   注意：本 SDK `showActionMenu` 的 buttons 为元组类型 `[Button, Button?, ...]`，须内联字面量传参。

构建状态：BUILD SUCCESSFUL。
