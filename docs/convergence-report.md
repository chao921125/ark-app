# 收敛报告 — 工程修复 + 在线音源（酷我 kw / 网易云 wy / 酷狗 kg / QQ音乐 tx）

> 日期：2026-09-05
> 工程：/Users/huangchao/Work/temp/lxmusic-hm

## 一、工程配置修复（DevEco Studio 可打开）

### 根因
缺少 `hvigorfile.ts`（根 + entry），SDK 版本格式错误（`5.0.0(12)` → `26.0.0`），modelVersion 错误，图标未使用 layered_image。

### 修复清单

| 文件 | 修复内容 |
|------|----------|
| `hvigorfile.ts`（新建） | hvigor 构建入口，`import { appTasks }` |
| `entry/hvigorfile.ts`（新建） | hap 构建入口，`import { hapTasks }` |
| `code-linter.json5`（新建） | 代码检查配置 |
| `entry/obfuscation-rules.txt`（新建） | 混淆规则占位 |
| `build-profile.json5` | SDK→`26.0.0`，加 `targetSdkVersion`、`signingConfig` |
| `oh-package.json5` | 加 `modelVersion:"26.0.0"`，hypium→1.0.25，加 hamock |
| `hvigor/hvigor-config.json5` | modelVersion→`26.0.0` |
| `entry/build-profile.json5` | 加 `resOptions`、release obfuscation、ohosTest target |
| `AppScope/app.json5` | 加 `buildVersion:"1"`，icon→`$media:layered_image` |
| `entry/src/main/module.json5` | icon→`$media:layered_image`，startWindowIcon→`$media:startIcon`，actions→`ohos.want.action.home`，description→`$string:EntryAbility_desc`，label→`$string:EntryAbility_label` |
| `entry/src/main/resources/base/element/string.json` | 字段名对齐标准：`EntryAbility_desc`、`EntryAbility_label` |
| `AppScope/resources/base/media/layered_image.json`（新建） | layered-image 定义 |
| `entry/src/main/resources/base/media/layered_image.json`（新建） | layered-image 定义 |
| `entry/src/main/ets/entryability/EntryAbility.ets` | 删除重复 `import { common }` |

### ⚠️ 待手动操作
png 图标文件需从标准项目复制（bash fork 失败无法自动完成）：
```bash
cp /Users/huangchao/Work/temp/arkts/AppScope/resources/base/media/foreground.png \
   /Users/huangchao/Work/temp/lxmusic-hm/AppScope/resources/base/media/foreground.png
cp /Users/huangchao/Work/temp/arkts/AppScope/resources/base/media/background.png \
   /Users/huangchao/Work/temp/lxmusic-hm/AppScope/resources/base/media/background.png
cp /Users/huangchao/Work/temp/arkts/entry/src/main/resources/base/media/foreground.png \
   /Users/huangchao/Work/temp/lxmusic-hm/entry/src/main/resources/base/media/foreground.png
cp /Users/huangchao/Work/temp/arkts/entry/src/main/resources/base/media/background.png \
   /Users/huangchao/Work/temp/lxmusic-hm/entry/src/main/resources/base/media/background.png
cp /Users/huangchao/Work/temp/arkts/entry/src/main/resources/base/media/startIcon.png \
   /Users/huangchao/Work/temp/lxmusic-hm/entry/src/main/resources/base/media/startIcon.png
```

## 二、在线音源（酷我 kw）功能

### 新增文件

| 文件 | 说明 |
|------|------|
| `utils/HttpUtil.ets` | HTTP 请求封装（@kit.NetworkKit，15s 超时，错误归一 BusinessError） |
| `api/kw/KwCrypto.ets` | DES-ECB-PKCS7 加密（纯 ArkTS 实现 FIPS 46-3 标准 DES，密钥 `ylzsxkwm`） |
| `api/kw/KwApi.ets` | kw 搜索/播放链接/歌词接口（防御式解析，结构变化不崩溃） |
| `api/kw/KwSource.ets` | SourceAdapter 实现，import 侧自动注册到 SourceRegistry |
| `pages/SearchView.ets` | 搜索页 UI（搜索栏 + 结果列表 + 加入歌单 + 点击播放） |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `player/PlayerKernel.ets` | `playIndexInternal` 支持 online 源：`player.url = onlineUrl` + 错误降级（TC-09） |
| `lyric/LyricManager.ets` | `loadForMusic` 增加在线歌词兜底：本地 .lrc 未找到 → SourceRegistry.getLyric |
| `pages/Index.ets` | 底栏增加"搜索"Tab（三栏：我的列表/搜索/设置） |

### 场景覆盖

| 场景 | 实现 | 测试用例 |
|------|------|----------|
| 1. 搜索在线歌曲 | SearchView.doSearch → KwApi.search | TC-01~TC-03 |
| 2. 在线播放 | PlayerKernel.playIndexInternal online 分支 | TC-04~TC-05 |
| 3. 在线歌词 | LyricManager.loadForMusic online 兜底 | TC-06 |
| 4. 加入歌单 | SearchView.addToPlaylist → ListPersistence.addMusic | TC-07~TC-08 |
| 5. 网络异常降级 | HttpUtil 15s 超时 + try-catch + toast | TC-09~TC-10 |
| 6. 混合队列一致性 | PlayerKernel 按 isLocalInfo 选择 fdSrc/url | TC-11 |

### 非功能要求

- ✅ 所有网络请求超时 15s（`HTTP_TIMEOUT_MS = 15000`）
- ✅ 错误统一捕获归一（hilog + toast），无未处理 Promise rejection
- ✅ 不修改既有本地播放行为（online 分支独立，local 路径不变）

## 三、在线音源（网易云 wy）功能

> 上游 v1.8.4 的 wy 播放链接已改为自定义源提供（`apis('wy')`），搜索/歌词内置。
> 本次移植采用 NeteaseCloudMusicApi 标准方案补齐直链（eapi song/enhance/player/url）。

### 新增文件

| 文件 | 说明 |
|------|------|
| `api/wy/WyCrypto.ets` | eapi/weapi 加密：MD5（cryptoFramework）+ AES-128-ECB/CBC-PKCS7（cryptoFramework）+ RSA NoPadding（ArkTS bigint modPow，上游固定公钥 n/e） |
| `api/wy/WyApi.ets` | wy 搜索（cloudsearch）/播放直链（song/enhance/player/url）/歌词（song/lyric/v1，含 fixTimeLabel 与 yrc 简化还原），防御式解析 |
| `api/wy/WySource.ets` | SourceAdapter 实现（id='wy'），import 侧自动注册 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `utils/HttpUtil.ets` | 新增 `httpPostForm`（application/x-www-form-urlencoded，UA/origin 可传，15s 超时，错误归一） |
| `pages/SearchView.ets` | 增加音源切换 chips（酷我/网易云），`doSearch` 按 `this.source` 取 adapter；队列 id 统一 `search_online` |
| `player/PlayerKernel.ets` | import WySource（触发注册） |
| `lyric/LyricManager.ets` | import WySource（触发注册） |

### 与上游实现的对齐点

- 搜索：上游启用 `/api/search/song/list/page`；本移植取标准 `/api/cloudsearch/pc`（响应歌曲字段 id/name/ar/al/dt/privilege/h/l/sq/hr 同构）
- 加密：eapi = `AES-ECB-PKCS7(key='e82ckenh8dichen8')` + MD5 digest（NeteaseCloudMusicApi 验证方案）；weapi 双重 AES-CBC + RSA NoPadding 一并实现备用
- 质量：128k 恒有，按 h/sq/hr 补 320k/flac/flac24bit（对齐上游 handleResult）
- 歌词：`[mm:ss:xx]→[mm:ss.xx]` 修复 + yrc 逐字歌词 JSON 行还原为标准 LRC

### 已知限制（wy）

1. **VIP/无版权曲目**直链接口返回 `url=null` → 走统一失败路径（toast + 跳过），不崩溃
2. **未登录态**：免费曲目通常可取 128k；部分高码率需登录 cookie（暂不支持，后续可在 WyApi 增加可选 cookie）

## 四、在线音源（酷狗 kg）功能

> 上游 v1.8.4 的 kg 播放链接已改为自定义源提供（`apis('kg')`），搜索/歌词内置。
> 本次移植采用社区验证的 `wwwapi.kugou.com/play/songinfo` + web 签名方案补齐直链。

### 新增文件

| 文件 | 说明 |
|------|------|
| `utils/CryptoUtil.ets` | 通用 MD5 摘要（cryptoFramework）+ bytesToHex 工具 |
| `api/kg/KgSign.ets` | signatureParams（对齐上游 `kg/util.js`：param_list sort + join + md5(keyparam+join-joined+body+keyparam)），android/web 双 keyparam |
| `api/kg/KgApi.ets` | kg 搜索（song_search_v2，GET 无需签名）/ 播放直链（wwwapi play/songinfo web 签名）/ 歌词（search→download `fmt=lrc`→base64 解码，规避 KRC zlib） |
| `api/kg/KgSource.ets` | SourceAdapter 实现（id='kg'），import 侧自动注册 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `model/MusicInfo.ets` | `QualityInfo` 增加可选字段 `hash?: string`（kg 按质量携带 FileHash） |
| `pages/SearchView.ets` | 音源切换 chips 增加酷狗，`SOURCE_CHIPS` 加 `{ id: 'kg', label: '酷狗' }` |
| `player/PlayerKernel.ets` | import KgSource（触发注册） |
| `lyric/LyricManager.ets` | import KgSource（触发注册） |

### 与上游实现的对齐点

- **签名**：`signatureParams` 完整移植上游 `kg/util.js`——`params.split('&').sort()` 整体排序后 `join('')`，sign = `md5(keyparam + joined + body + keyparam)`；android keyparam=`OIlwieks28dk2k092lksi2UIkp`，web keyparam=`NVPh5oo715z5DIWAe0lhMDsWXXQV4hwt`
- **搜索**：`songsearch.kugou.com/song_search_v2` GET 无需签名，响应 `data.lists[]` 含 Grp 子项（同名多版本），用 Audioid+FileHash 去重
- **直链**：`wwwapi.kugou.com/play/songinfo` + web 签名（上游 v1.8 两端均无内置 musicUrl.js，走自定义源；本方案为社区验证的可播放方案）
- **歌词**：上游 KRC 格式需 zlib inflate（pako），ArkTS 无内存级 zlib 且无法装三方库 → 强制请求 `fmt=lrc` 让服务端转换，规避 zlib 依赖
- **质量映射**：128k→`hash`（FileHash）/ 320k→`320hash` / flac→`flacHash` / flac24bit→`hqhash`，对齐上游 `qualityFilter` 顺序

### 已知限制（kg）

1. **VIP/无版权曲目**直链接口返回 `url=null` → 走统一失败路径（toast + 跳过），不崩溃
2. **KRC 逐字歌词**：本次强制 `fmt=lrc` 取标准 LRC，逐字时间戳降级为逐行（后续可引入 paho/自实现 zlib inflate 恢复）
3. **Grp 子项**：同名多版本歌曲仅取主项 FileHash，子项不展开（与上游 `filterSongList` 一致）

## 五、在线音源（QQ音乐 tx）功能

> 上游 v1.8.4 的 tx 播放链接已改为自定义源提供（`apis('tx')`），搜索/歌词内置。
> 本次移植采用社区验证的 `vkey.GetVkeyServerBase64 / CgiGetVkey` 方案补齐直链。

### 新增文件

| 文件 | 说明 |
|------|------|
| `api/tx/TxSign.ets` | zzcSign（对齐上游 `tx/utils/crypto.js`：SHA1 → PART_1/PART_2 索引取位 → SCRAMBLE_VALUES 异或 → base64 去 `/+=` → 小写拼接 zzc 前缀） |
| `api/tx/TxApi.ets` | tx 搜索（music.search.SearchCgiService，POST JSON + zzc 签名，code!=0 重试 ≤5）/ 播放直链（vkey.GetVkeyServerBase64 CgiGetVkey，filename={prefix}{songmid}{strMediaMid}.{ext}）/ 歌词（fcg_query_lyric_new.fcg，base64 解码含翻译歌词） |
| `api/tx/TxSource.ets` | SourceAdapter 实现（id='tx'），import 侧自动注册 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `utils/HttpUtil.ets` | 新增 `httpPostJson`（application/json，15s 超时，错误归一） |
| `utils/CryptoUtil.ets` | 新增 `sha1Hex`（SHA1 摘要）+ `base64DecodeUtf8`（base64→UTF-8 字符串） |
| `model/MusicInfo.ets` | `MusicInfoMetaOnline` 增加可选字段 `songmid?: string` / `strMediaMid?: string`（tx 构造直链 filename） |
| `pages/SearchView.ets` | 音源切换 chips 增加QQ音乐，`SOURCE_CHIPS` 加 `{ id: 'tx', label: 'QQ音乐' }` |
| `player/PlayerKernel.ets` | import TxSource（触发注册） |
| `lyric/LyricManager.ets` | import TxSource（触发注册） |

### 与上游实现的对齐点

- **签名**：`zzcSign` 完整移植上游 `tx/utils/crypto.js`——sha1(payload JSON) 后按 `PART_1_INDEXES=[23,14,6,36,16,40,7,19]` / `PART_2_INDEXES=[16,1,32,12,19,27,8,5]` 取位（索引 40 越界取空串，与上游 join 行为一致），`SCRAMBLE_VALUES` 20 字节与 hash 逐字节异或后 base64 去除 `/+=`，整体小写
- **搜索**：payload/comm 设备参数完整对齐上游 `musicSearch.js`；`sign` 输入与请求体为同一 JSON 串（键序一致保证签名有效）；code!=0 重试逻辑对齐（≤5 次，每次重新随机 searchid）
- **直链**：上游 v1.8 无内置 musicUrl.js（走自定义源），采用社区验证方案 `vkey.GetVkeyServerBase64 / CgiGetVkey`；质量映射 128k→M500 / 320k→M800 / flac→F000 / flac24bit→RS02；purl 拼 `https://isure.stream.qqmusic.qq.com/`
- **歌词**：对齐上游 `lyric.js`（Referer: y.qq.com/portal/player.html），`lyric`/`trans` base64(UTF-8) 解码 → LyricInfo.lyric/tlyric
- **封面**：对齐上游 img 逻辑（专辑 mid 封面优先，无专辑回退歌手 mid 封面）

### 已知限制（tx）

1. **VIP/无版权曲目**purl 为空 → 走统一失败路径（toast + 跳过），不崩溃
2. **flac24bit 用 RS02 前缀**：社区方案通用映射，部分 Hi-Res 曲目若取不到可回退 320k
3. **搜索接口较重**：每次搜索一次签名 POST（SHA1 + cryptoFramework），重试最多 5 次在上游对齐范围内

## 六、在线音源（咪咕 mg）功能

> 上游 v1.8.4 的 mg 播放链接已改为自定义源提供（`apis('mg')`），搜索/歌词内置。
> 本次移植采用 listen1 社区验证的 `MIGUM3.0/strategy/pc/listen/v1.0` 方案补齐直链。

### 新增文件

| 文件 | 说明 |
|------|------|
| `api/mg/MgApi.ets` | mg 搜索（jadeite v3 searchAll，md5 签名 headers，code==='000000'，二维 resultList + copyrightId 去重）/ 播放直链（listen/v1.0，toneFlag PQ/HQ/SQ/ZQ，`//` 补 https、`+` 转 %2B）/ 歌词（lrcUrl/trcUrl 直取文本，缺失时 resourceinfo.do 补全） |
| `api/mg/MgSource.ets` | SourceAdapter 实现（id='mg'），import 侧自动注册 |

### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `model/MusicInfo.ets` | `MusicInfoMetaOnline` 增加可选字段 `copyrightId?` / `contentId?` / `lrcUrl?` / `mrcUrl?` / `trcUrl?`（mg 直链与歌词需要） |
| `pages/SearchView.ets` | 音源切换 chips 增加咪咕，`SOURCE_CHIPS` 加 `{ id: 'mg', label: '咪咕' }` |
| `player/PlayerKernel.ets` | import MgSource（触发注册） |
| `lyric/LyricManager.ets` | import MgSource（触发注册） |

### 与上游实现的对齐点

- **搜索签名**：对齐上游 `musicSearch.js` 的 `createSignature`——`sign = md5(text + '6cdc72a439cef99a3418d2a78aa28c73' + 'yyapp2d16148780a1dcc7408e06336b98cfd50' + deviceId + timestamp)`，deviceId 固定 `963B7AA0D21511ED807EE5846EC87D20`，headers 带 uiVersion/channel/timestamp/sign
- **搜索解析**：对齐上游 `filterData`——二维 `resultList` 展开、copyrightId 去重；`audioFormats.formatType`：PQ→128k / HQ→320k / SQ→flac / ZQ24→flac24bit（size=asize??isize）；封面 img3||img2||img1 无 http 前缀补 `d.musicapp.migu.cn`
- **直链**：上游 v1.8 无内置 musicUrl.js（走自定义源），采用 listen1 `bootstrap_track` 的 `MIGUM3.0/strategy/pc/listen/v1.0`（headers channel=0146951）；contentId 缺失时二次查询 `resourceinfo.do`（POST resourceId=copyrightId）补全
- **歌词**：对齐上游 `lyric.js` 的 getText headers（Referer: app.c.nf.migu.cn + channel）；lrcUrl 直取 LRC 文本，trcUrl 取翻译歌词（失败不影响主歌词）

### 已知限制（mg）

1. **VIP/无版权曲目**直链返回空 url → 走统一失败路径（toast + 跳过），不崩溃
2. **mrc 逐字歌词未实现**：需 TEA-64bit 变体解密（上游 `mg/utils/mrc.js`），首版降级只用 lrcUrl 标准歌词（与 kg KRC 决策一致；仅当歌曲无 lrcUrl 时歌词为空）
3. **直链为 listen1 社区方案**：上游 v1.8 无内置 mg musicUrl.js；PC listen 接口对部分新歌可能返回试听片段

## 七、核心功能补全（音质选择 + 播放队列）

> 全面对齐上游 playerSetting.playQuality 与 PlayDetail 播放列表交互。

### 1. 在线播放音质选择（对齐上游 `playerSetting.playQuality`）

| 文件 | 修改内容 |
|------|----------|
| `model/AppSettings.ets` | 新增 `PlayQuality` 类型（128k/320k/flac/flac24bit）、`QUALITY_LADDER` 降级链、`isPlayQuality` 校验；`AppSettings` 加 `playQuality`（默认 128k） |
| `persistence/SettingPersistence.ets` | load merge 增加 `playQuality`（非法值回落默认，旧数据兼容） |
| `store/ListStore.ets` | `applySettings` 增加 `PlayerKernel.setPlayQuality(s.playQuality)` |
| `player/PlayerKernel.ets` | 新增 `setPlayQuality` + `resolveQuality`（质量降级：请求质量不可用时按 flac24bit→flac→320k→128k 取请求质量及以下的最高可用；全无取列表首项）；在线播放两处硬编码 `'128k'` 改为按设置解析 |
| `pages/SettingView.ets` | "在线播放音质"四选一 UI（Radio 组，与播放模式风格一致） |

### 2. 播放队列查看与管理（对齐上游 PlayDetail 播放列表）

| 文件 | 修改内容 |
|------|----------|
| `player/PlayerKernel.ets` | 新增 `removeAt`（移除非当前曲修正索引；移除当前曲自动续播同位置原下一曲，队列空则停止）+ `notifyQueueChanged`（`playQueueRev` 版本号）；`setList`/`init` 同步队列版本 |
| `pages/PlayDetail.ets` | 控制区新增播放队列按钮（`ic_queue.svg`）；半模态 `bindSheet` 队列弹层：当前曲高亮、点击切播、单曲移除、空态提示；`@Watch('refreshQueue')` 跟随队列变化 |

## 八、喜欢的音乐 + 换源播放

### 1. 喜欢的音乐（对齐上游 likeList 机制）

> 上游机制：default 列表即"喜欢的音乐"，收藏 = 加入 default 列表，取消收藏 = 移出。

| 文件 | 修改内容 |
|------|----------|
| `model/SongList.ets` | 新增 `DEFAULT_LIST_NAME = '喜欢的音乐'`；`ListPersistence.load()` 强制 default 列表改名（兼容旧"默认列表"数据，不可重命名/删除约束不变） |
| `persistence/ListPersistence.ets` | 新增 `isLiked(musicId)` / `toggleLike(music)`（切换收藏返回最新状态）+ `notifyLikeChanged`（`likeListRev` 版本号） |
| `components/MusicListItem.ets` | 新增 `liked` @Prop + `onToggleLike` 回调；时长前红心按钮（`stopPropagation` 防误触发行播放） |
| `pages/MyListView.ets` | 歌曲行接入收藏；ForEach key 携带 liked 状态（收藏变化即时重建行）；`@Watch('refreshList')` 跟随 likeListRev |
| `pages/SearchView.ets` | 搜索结果行加红心收藏（toast 反馈）；key 携带 liked + likeListRev |
| `pages/PlayDetail.ets` | 顶栏红心收藏当前播放曲（跟随 likeListRev 与切歌刷新） |
| `pages/SettingView.ets` | 清除全部数据后递增 likeListRev 刷新各页收藏状态 |

### 2. 换源播放（四期功能提前，对齐上游换源交互）

> 上游交互：PlayDetail 歌曲信息区"换源"按钮 → 选源搜索同名歌曲 → 确认候选替换当前播放。

| 文件 | 修改内容 |
|------|----------|
| `player/PlayerKernel.ets` | 新增 `replaceCurrent(music)`：替换队列当前位置并立即播放，队列其余曲目不变 |
| `pages/PlayDetail.ets` | 顶栏换源按钮（`ic_goto.svg`）；`bindSheet` 换源弹层：五源 chips 选源搜索（关键词 = 歌手 + 歌名，过滤同 id）、候选列表（歌手·专辑副标题）、点击候选即换源播放；搜索失败/无匹配 toast |

## 九、桌面歌词双模式（三期收尾）

> 对齐上游桌面歌词单行模式；HarmonyOS 侧实现为双模式：
> 真全局悬浮窗（`window.createWindow` + `WindowType.TYPE_FLOAT=8`，API 9+）优先，
> 权限缺失（错误码 201）/设备不支持（801）/窗口类型无效（1300004）时自动回落应用内歌词条。

| 文件 | 修改内容 |
|------|----------|
| `lyric/FloatLyricWindow.ets` | 新增悬浮窗管理器：`init(context)`（对齐 MediaSessionController 模式）/ `syncState(on)`（创建/销毁 + `floatLyricWindowActive` 状态）/ `findWindow()`（页面拖动用）；窗口尺寸按屏幕 86% 宽计算、透明背景 |
| `pages/FloatLyricPage.ets` | 新增悬浮窗页面（`main_pages` 注册）：当前歌词行（共享 LyricManager 缓存与 AppStorage 进度）、PanGesture 拖动（moveTo，坐标初始化自 windowRect 防跳位）、关闭按钮、点击歌词展开播放详情 |
| `module.json5` | 声明 `ohos.permission.SYSTEM_FLOAT_WINDOW` + `perm_float_window` 文案 |
| `store/ListStore.ets` | `setShowFloatLyric` 统一入口：持久化 + `FloatLyricWindow.syncState`（真悬浮窗优先，失败回落） |
| `components/FloatLyricBar.ets` | 显示条件加 `floatLyricWindowActive` 互斥（悬浮窗模式时应用内条隐藏） |
| `entryability/EntryAbility.ets` | 启动时 `FloatLyricWindow.init(context)` 注入上下文 |
| `pages/SettingView.ets` | "悬浮歌词"改为"桌面歌词"开关走统一入口，附当前模式提示文案 |

## 十、PC 同步（三期收尾，最后一个核心缺口）

> 与 lx-music-desktop 桌面版互通：HTTP 认证 + WebSocket 同步，协议逐字节对齐上游 `src/plugins/sync/`（v1.8.4）。

### 协议实现（对齐上游要点）

| 环节 | 上游行为 | 本工程实现 |
|------|----------|------------|
| 握手 | GET `/hello` 校验 `Hello~::^-^::~v4~` 版本；GET `/id`（前缀 `OjppZDo6`）取服务器 id | `SyncAuth.hello/getServerId` |
| 首连认证（连接码） | key=base64(md5(authCode)[0:16])；客户端生成 RSA2048（SPKI/PKCS8）；msg=AES-ECB(`lx-music auth::\n{pub}\n{device}\nlx_music_mobile`)；GET `/ah`（header m）→ 响应 RSA-OAEP(SHA1+MGF1) 解密 → KeyInfo{key, clientId} | `SyncAuth.codeAuth` + `SyncCrypto`（cryptoFramework：AES128\|ECB\|PKCS7、RSA2048\|OAEP\|SHA1\|MGF1_SHA1） |
| 复连认证 | AES 加密 + header i(clientId)/m → 响应解密须为 helloMsg | `SyncAuth.keyAuth`；KeyInfo 持久化（PreferencesUtil） |
| WS 连接 | `ws://host/socket?i={clientId}&t=AES('lx-music connect')`；服务端每 30s 发 'ping'，31s 超时断开；断线指数退避重连（2s→30s） | `SyncManager`（@kit.NetworkKit webSocket + 心跳/重连） |
| 消息层 | >1024 字符 `'cg_'` + gzip base64（v1.8 已去消息体 AES）；否则原文 | `SyncMsg`（@ohos.zlib 经 cacheDir 临时文件中转） |
| RPC | message2call wire 协议：REQUEST=[0,name,path,args,callbacks] / RESPONSE=[1,name,err,result?] | `SyncMsg.buildRequest/buildResponse` + pendingCallbacks |
| 列表同步 | getEnabledFeatures → list_sync_get_sync_mode（弹窗）→ get_md5/get_list_data/set_list_data/onListSyncAction → list_sync_finished → finished | `SyncManager.dispatchCall` + `SyncListDataOps` |

### 新增/修改文件

| 文件 | 内容 |
|------|------|
| `sync/SyncConstants.ets` | SYNC_CODE/SYNC_CLOSE_CODE/SyncMode/KeyInfo/Status 常量 |
| `sync/SyncCrypto.ets` | AES-128-ECB(PKCS7) + RSA2048 生成/解密 + authCode 派生 key |
| `sync/SyncAuth.ets` | hello/getServerId/codeAuth/keyAuth/auth（HTTP 走 HttpUtil） |
| `sync/SyncMsg.ets` | gzip 传输层（'cg_' 前缀）+ message2call RPC 编解码 |
| `sync/SyncListData.ets` | ListData 转换（defaultList=喜欢的音乐）、setLocalListData 全量覆盖、handleRemoteListAction 增量动作（overwrite/create/remove/update/reorder/music add/remove/clear/overwrite；move/update/update_position V1 忽略） |
| `sync/SyncManager.ets` | WS 客户端总控：认证、心跳、重连、RPC 分发、模式选择 Promise、状态广播（syncStatusJson/Rev） |
| `persistence/ListPersistence.ets` | 扩展 `overwriteSyncData` / `addListAt` / `reorderUserLists` / `overwriteListMusic`；notifyDataChanged 统一刷新 |
| `pages/SettingView.ets` | "PC 同步"分区：状态、地址/连接码输入、连接/断开；同步模式选择弹层（合并×2 / 覆盖×2 / 取消） |
| `entryability/EntryAbility.ets` | `SyncManager.init(context)` |

## 十一、自定义音源完整迁移（对齐上游 user-api-preload.js）

> 用户反馈：仅支持本地导入、导入后失败/不识别。逐项对照上游 `android/app/src/main/assets/script/user-api-preload.js`（v1.8.4 WebView 运行时）修复。

### 根因与修复

| 问题 | 根因 | 修复 |
|------|------|------|
| 脚本运行时崩溃（大量源"导入失败"） | 宿主 lx.utils.crypto 仅 md5，`aesEncrypt/rsaEncrypt` 直接 throw；生态脚本依赖其做 API 签名 | 宿主 HTML 重写：纯 JS AES-128（CBC PKCS7 / ECB）+ RSA/ECB/NoPadding（BigInt modPow + SPKI DER 解析）+ randomBytes |
| 契约不兼容（脚本 `.catch/.then` 崩溃、版本判断失败） | lx.version='0.0.2'（上游 '2.0.0'）；send/on 返回 undefined（上游返回 Promise）；on 接受 updateAlert（上游仅 request） | 宿主对齐：version 2.0.0、send/on 返回 Promise、inited/updateAlert 各仅一次（重复 send 报 'Script is inited'） |
| sources 不识别 | 上游 handleInit 按 allSources=[kw,kg,tx,wy,mg,local] 过滤、要求 type=='music'、actions/qualitys 按内置列表归一化；本工程原样透传任意 id | 宿主 handleInit 对齐过滤归一化（在线源额外放行 lyric，desktop 版行为，本工程 LyricManager 依赖） |
| 结果校验缺失 | 上游 handleRequest：musicUrl/pic 必须 http(s) URL 且 ≤2048、lyric 经 verifyLyricInfo（长度上限）；本工程无校验 | 宿主 handleRequest 对齐（含 pic action 分发） |
| 导入"失败"提示（实际成功） | importFromPicker 同步等待 inited（异步握手）→ 时序竞争恒返回失败文案 | 导入仅校验+保存+执行，结果经 toast 异步反馈（对齐上游） |
| 无网络导入 | 未实现 | `UserApiManager.importFromUrl`（httpGetText 下载→saveAndRun 复用）+ SettingView "从 URL 导入"输入区 |
| request 差异 | 上游 method 默认 'get'、timeout 上限 60s | 对齐；request 保持返回 abort 函数 |

### 修改文件

| 文件 | 内容 |
|------|------|
| `resources/rawfile/user_api_host.html` | 整体重写 lx 环境（对齐 preload 契约 + 纯 JS crypto） |
| `api/user/UserApiManager.ets` | importFromPicker 时序修复、新增 importFromUrl、saveAndRun 抽取、校验放宽（lx + inited/EVENT_NAMES） |
| `pages/SettingView.ets` | 网络导入 UI（URL 输入 + 下载导入按钮）、导入成功提示文案调整 |

## 十二、已知限制

1. **png 图标需手动复制**（bash fork 失败，见上方命令）
2. **本机无 DevEco Studio**，无法真机构建验证
3. **kw API 为 HTTP**（非 HTTPS），需在 module.json5 中确认明文流量允许（HarmonyOS 默认允许 HTTP）
4. **DES 加密为纯 ArkTS 实现**（无 @kit.CryptoKit 依赖），性能足够（搜索请求每次仅 1 次加密）
5. **wy RSA 用 ArkTS bigint**（非 cryptoFramework RSA，避免 X.509 SPKI 手工 DER 编码），指数 65537 快速幂仅 ~17 次模乘，性能无虞
6. **kg 歌词降级 LRC**：KRC 逐字格式需 zlib inflate，ArkTS 无内存级 zlib → 强制 `fmt=lrc` 取标准 LRC（逐字降级为逐行）
7. **kg 直链为社区方案**：上游 v1.8 两端均无内置 kg musicUrl.js（走自定义源），本方案采用 wwwapi play/songinfo + web 签名
8. **tx 直链为社区方案**：上游 v1.8 无内置 tx musicUrl.js（走自定义源），本方案采用 vkey.GetVkeyServerBase64 CgiGetVkey；签名/搜索/歌词与上游内置实现完全对齐
9. **mg 直链为社区方案**：上游 v1.8 无内置 mg musicUrl.js（走自定义源），本方案采用 listen1 MIGUM3.0 strategy/pc/listen/v1.0；搜索签名/歌词 headers 与上游内置实现完全对齐
10. **音质降级为本地策略**：请求质量不在搜索结果质量列表时按降级链取可用质量（避免必然失败的直链请求）；VIP/无版权曲目各源仍走统一失败路径
11. **换源候选为同名搜索结果**：按"歌手 + 歌名"关键词搜索取首个匹配列表，人工点选确认（对齐上游行为）；收藏/歌单中记录仍为原源歌曲，换源仅替换当前播放队列项
12. **桌面歌词悬浮窗需 ACL 签名**：`SYSTEM_FLOAT_WINDOW` 为 system_basic 级权限，普通签名（AGC 上架）下 `createWindow` 返回 201 自动回落应用内歌词条；需 ACL 使能签名（调试 profile）方可用真悬浮窗。悬浮窗随应用重启不自动恢复，需重新开启
13. **悬浮窗点击展开播放详情**仅应用在前台时可见（悬浮窗点击不唤醒应用主窗口）
14. **PC 同步 V1 限制**：① 本地改动不实时上行（上游 isRemote 回环阻断未复刻，下次连接合并同步）；② 上游 love 内置列表双向固定空（本工程无对应列表，桌面版 love 数据不参与同步）；③ list_music_move/update/update_position 三个增量动作忽略（全量覆盖/合并模式不受影响）；④ 未与真实桌面版联调（需局域网桌面版环境，协议按上游 v1.8.4 源码逐字节对齐）；⑤ dislike（不喜欢列表）特性未声明，服务端不发起该模块同步15. **自定义源宿主为 ArkWeb 方案**：无 native JSVM（三方应用需 NDK），脚本运行于隐藏 Web 组件沙箱页；上游 QuickJS 的严格沙箱（冻结 globalThis、禁 eval/Function 动态执行）未完全复刻（ArkWeb 无法阻止 DOM/window 访问，宿主页无敏感数据，风险可接受）；utils.crypto.aesDecrypt / utils.zlib 上游亦未提供（preload 注释保留），生态脚本无依赖
16. **自定义源 pic action**：宿主已支持分发，但本工程无调用方（封面由内置源提供），未暴露 getPic 链路
17. **在线源 lyric 放行**：上游 mobile preload 过滤在线源 lyric，本工程保留（与 desktop 一致，LyricManager 自定义源歌词链路依赖）
## 十二、架构重构确认 + 播放链路修复（musicInfo 形状映射）

> 项目已重构自定义音源引擎为 `core/source/`（SourceEngine 沙箱引擎 + SourceStore + LxHttp + LxMetadata + LxTypes + rawfile lx_utils.js/lx_preload.js/lx_host.html），替代旧 UserApiManager/user_api_host.html 方案。播放链路：SourceEngine（自定义源）→ 内置源兜底（SourceRegistry）→ AVPlayer。
> 用户反馈"搜索成功但无法播放"，根因与修复如下。

### 根因

| # | 问题 | 说明 |
|---|------|------|
| 1 | **musicInfo 形状不匹配（主因）** | 洛雪源脚本读顶层 `musicInfo.songmid`（kw/wy/mg=歌曲 id、**kg=FileHash**、tx=mid）与 `musicInfo.hash`、`musicInfo.copyrightId`（mg）；本工程 MusicInfo 的 songId 在 meta 内、hash 在 meta.qualitys[]。PlayerKernel 传 `JSON.stringify(music)` 原样进沙箱 → 脚本拿不到 id → 拼不出直链请求 → "无法播放"（搜索不受影响） |
| 2 | 歌词链路 JSON 误当 LRC | SourceEngine.getLyric 返回 `result.data` 的 JSON 文本（{lyric,...}），LyricManager 直接 LyricParser.parse → 0 行 |

### 修复

| 文件 | 内容 |
|------|------|
| `core/source/SourceEngine.ets` | 新增 `toLxMusicInfoJson(musicInfoJson, source, quality)`：songmid（kg=hash、tx=meta.songmid、其余=meta.songId）、hash（按请求质量匹配 meta.qualitys[].hash）、mg 顶层 copyrightId；getMusicUrl/getLyric/getPic 三处 payload 均用转换后的 JSON |
| `lyric/LyricManager.ets` | getLyric 返回值 JSON.parse 取 lyric 字段（容错直接返回 LRC 文本的脚本） |

### 待真机验证（无本地网络实测手段）

1. 内置源兜底直链接口（kw mobi.s / wy eapi player/url / kg wwwapi / tx vkey / mg listen）——上游 v1.8.4 已无内置直链，本工程为社区方案，接口可用性需真机确认
2. AVPlayer 播放直链（部分站点要求 UA/Referer，AVPlayer 无法自定义请求头）
3. 自定义源脚本端到端（修复后脚本应能拿到 songmid/hash/copyrightId）
