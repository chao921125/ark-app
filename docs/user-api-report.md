# 自定义源脚本（JSVM）实施报告（三期）

> 日期：2026-09-05
> 工程：/Users/huangchao/Work/temp/lxmusic-hm
> 上游参照：lx-music-mobile `src/utils/nativeModules/userApi`（QuickJS）+ 洛雪移动版自定义源脚本 v2 契约

## 一、引擎选型说明（重要）

需求原名"自定义源脚本（JSVM）实现"。经核实（OpenHarmony `interface_sdk-js` 仓库与官方文档）：

1. **三方应用没有 ArkTS 侧的 `@ohos.jsvm` 模块**，JSVM-API 仅有 NDK C/C++ 形态（`jsvm.h` / `OH_JSVM_*`，`libjsvm.so`）；
2. 使用 C/C++ JSVM 需要为纯 ArkTS 工程引入 NDK 原生模块（CMake + .so + d.ts），在本机无 DevEco/编译器的环境下不可验证，风险过高；
3. 因此本实现采用 **隐藏 ArkWeb（Chromium 内核）作为脚本沙箱**：完整 ES6+/Promise 引擎、
   `registerJavaScriptProxy`（JS→ArkTS 同步桥）+ `runJavaScript`（ArkTS→JS）双向桥接，
   引擎细节全部收敛在 3 个文件中，未来若引入 NDK JSVM 可替换而契约层不动。

## 二、架构

```
pages/Index.ets                    Stack 最底层挂载 UserApiHost（1x1 隐藏 Web，保持 JS 运行）
components/UserApiHost.ets         Web 组件 + LxHostBridge（注册 lxHost 代理）+ 就绪探测
resources/rawfile/user_api_host.html   沙箱页：lx 对象构建 / Buffer polyfill / 纯 JS md5 / 桥协议
api/user/UserApiManager.ets        生命周期（导入/存储/握手/分发/超时）+ getMusicUrl/getLyric
```

### 桥协议（lxHost.dispatch(kind, id, data, data2)，参数均为字符串）

| kind | id | data | data2 | 方向 |
|---|---|---|---|---|
| `event` | runId | 事件名 | - | 脚本调 `lx.on` 时上报 |
| `send` | runId | 事件名 | payload JSON | 脚本调 `lx.send`（inited 握手 / updateAlert） |
| `request` | callId | 参数 JSON | - | 脚本调 `lx.request`，宿主代发 HTTP |
| `handlerResult` | callId | '1'/'0' | 结果 JSON | `request` 处理器 Promise 结算 |

ArkTS→JS 用 `runJavaScript`：`__setupLx(meta)` 建立全新 lx 会话、`__dispatchRequest(callId, paramsJson)`
调用 request 处理器、`__hostResolve(callId, ok, json)` 回注 lx.request 结果、`__resetLx()` 注销。

## 三、脚本契约支持范围（对齐 v2）

| 契约 | 支持 | 说明 |
|---|---|---|
| `lx.EVENT_NAMES`（request/inited/updateAlert） | ✅ | Object.freeze |
| `lx.on('request', handler)`（返回 Promise） | ✅ | 未注册即 send inited → 握手失败 |
| `lx.send('inited', {status, sources})` | ✅ | sources 校验（name/type/actions/qualitys），10s 握手超时 |
| `lx.send('updateAlert', {msg, ...})` | ✅ | toast 透传 |
| `lx.request(url, options, cb(err, resp, body))` | ✅ | method/headers/body/form 支持；formData 暂不支持；任何状态码均回传；超时受宿主钳制（1s~30s） |
| `lx.utils.buffer.from / bufToString` | ✅ | 同时注入 `window.Buffer` polyfill（from/isBuffer/alloc/concat/byteLength + toString(enc)） |
| `lx.utils.crypto.md5 / randomBytes` | ✅ | 纯 JS md5（RFC 1321 数据驱动）+ crypto.getRandomValues，同步无往返 |
| `lx.utils.crypto.aesEncrypt / rsaEncrypt` | ❌ | 抛明确错误（移动端 QuickJS 宿主为 C 实现；本宿主暂缺，后续可经宿主 cryptoFramework 桥接） |
| `lx.utils.zlib` | ❌ | 对齐上游移动端行为（未提供） |
| `lx.currentScriptInfo / VERSION / env / envParams` | ✅ | env='mobile'；VERSION='0.0.2' |
| `setTimeout / clearTimeout / console` | ✅ | ArkWeb 原生提供 |

**musicInfo 兼容性包装**：传给脚本前自动把本工程 MusicInfo 转为上游形状——
`songmid`、`meta.musicId`、顶层 `hash`（取首个带 hash 的质量，kg 源）。

## 四、应用集成

| 文件 | 内容 |
|---|---|
| `player/PlayerKernel.ets` | 在线曲目取直链：`UserApiManager.isEnabled()` 且脚本声明支持该源 `musicUrl` 时**优先走脚本**，失败/空串回落内置 SourceRegistry（TC-09 失败路径不变） |
| `lyric/LyricManager.ets` | 本地 .lrc 未命中 → 脚本 `lyric` action 优先 → 内置源兜底 |
| `model/AppSettings.ets` + `SettingPersistence.ets` | 新增 `customSourceEnabled`（默认关，持久化） |
| `store/ListStore.ets` | 启动时把开关同步给 UserApiManager |
| `pages/SettingView.ets` | 「自定义音源」卡片：脚本信息（名称/作者/版本/支持源）、优先开关、导入/更新/移除（移除有确认）、错误状态展示 |
| `pages/Index.ets` + `components/UserApiHost.ets` | 隐藏宿主组件挂载与就绪探测（验证 lxHost 注入完成后才允许跑脚本） |
| `entryability/EntryAbility.ets` | 启动末尾恢复已导入脚本（宿主就绪后自动初始化，失败不阻塞启动） |
| `utils/FileScanner.ets` | `pickUserScript`（.js 单选）+ `readTextFromUri`（fd 读文本） |

脚本存储：`<filesDir>/userapi/script.js` + Preferences `user_api_meta_v1`（元信息）。
脚本调用统一 15s 超时；失败一律回落内置源，不阻塞播放主链路。

## 五、验证状态与已知限制

1. 本机无 DevEco，未编译验证；ArkTS 侧按既有工程模式人工审查（单例导出、Record 用法、桥参数全字符串化）。
2. `aesEncrypt/rsaEncrypt` 未实现：依赖这两个原语的脚本会收到明确错误并回落内置源（内置 kw/wy/kg/tx/mg 已覆盖常规直链需求）。
3. `lx.request` 仅支持文本 body/响应（音乐直链脚本均为 JSON/表单交互，不受影响）；formData（multipart）不支持。
4. 沙箱页加载于本地 resource 协议，脚本无法访问应用文件系统；出网仅经宿主 `lx.request`（15s 规范超时）。
5. 若设备上将 Web 组件 JS 暂停（极端省电策略），脚本初始化会超时报错，播放仍走内置源，不影响核心功能。
