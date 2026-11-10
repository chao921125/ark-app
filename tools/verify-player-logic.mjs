/**
 * 播放域纯逻辑的确定性验证台
 *
 * 【它测的是什么】
 * 直接运行 entry/src/main/ets 下 **未经改写的真实源码**：
 *   core/queue/PlayModePolicy.ets   播放模式策略
 *   core/queue/PlayQueue.ets         播放队列
 *   persistence/ListPersistence.ets  歌单持久化（去重与批量落盘）
 *   model/SongList.ets               歌单模型
 * 覆盖 docs/refactor-plan-v2.md §3.3 的边界规则，以及「保存队列为歌单」的落盘行为。
 *
 * 【为了能在 Node 里跑，做了什么等价改写】
 * 仅改写 import 语句，不动任何逻辑：
 *   1. 只用作类型的绑定改为 `import type { ... }`（Node 的类型剥离要求显式 import type）
 *   2. 相对路径补 .ts 扩展名（Node ESM 要求显式扩展名）
 *   3. @kit.PerformanceAnalysisKit 用本地桩件替代（Node 无法加载系统 SDK）
 *   4. persistence/PreferencesUtil 用内存实现替代（真实实现依赖 @kit.ArkData）
 * 逻辑代码逐字节保持不变。
 */
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { tmpdir } from 'node:os'

const HERE = dirname(fileURLToPath(import.meta.url))
const SRC = resolve(HERE, '../entry/src/main/ets')
const WORK = resolve(tmpdir(), 'arkapp-verify-' + process.pid)

rmSync(WORK, { recursive: true, force: true })
mkdirSync(WORK, { recursive: true })

// ---- @kit.PerformanceAnalysisKit 桩件（Node 无法加载系统 SDK） ----
const kitDir = resolve(WORK, 'node_modules/@kit/PerformanceAnalysisKit')
// ---- @kit.PerformanceAnalysisKit 桩件（Node 无法加载系统 SDK） ----
// @kit.* 不是合法 npm 包名，因此把 import 说明符直接改写为桩件文件的绝对路径
const KIT_STUB = resolve(WORK, 'kit/PerformanceAnalysisKit.ts')
mkdirSync(dirname(KIT_STUB), { recursive: true })
writeFileSync(KIT_STUB, `
export const hilog = {
  info: () => {}, debug: () => {}, warn: () => {}, error: () => {}, fatal: () => {},
}
`)

// ---- AppStorage 桩件（ArkUI 全局对象，Node 里不存在） ----
globalThis.AppStorage = {
  _store: new Map(),
  get(key, fallback) { return this._store.has(key) ? this._store.get(key) : fallback },
  setOrCreate(key, value) { this._store.set(key, value) },
  has(key) { return this._store.has(key) },
  delete(key) { this._store.delete(key) },
}
/** Preferences 内存实现：接口与真实实现一致，并记录落盘次数 */
mkdirSync(resolve(WORK, 'persistence'), { recursive: true })
writeFileSync(resolve(WORK, 'persistence/PreferencesUtil.ts'), `
class PreferencesUtilImpl {
  private store = new Map()
  writes = 0
  async init(_context) {}
  async getString(key) { return this.store.has(key) ? this.store.get(key) : '' }
  async setString(key, value) { this.writes++; this.store.set(key, value) }
  async remove(key) { this.store.delete(key) }
  async clear() { this.store.clear() }
}
export const PreferencesUtil = new PreferencesUtilImpl()
`)

/** 把 .ets 复制成可被 Node 执行的 .ts（仅改写 import 语句） */
function adapt(relSrc, relDst) {
  let code = readFileSync(resolve(SRC, relSrc), 'utf-8')
  // 混合 import 拆分：类型绑定与运行时值分开
  // （ArkTS 编译器会自动省略类型导入，Node 的 ESM 不会，必须显式 import type）
  const TYPE_ONLY = new Set(['MusicInfo', 'PlayMode', 'SongList', 'AddMusicLocationType'])
  code = code.replace(
    /import\s*\{([^}]+)\}\s*from\s*'(\.[^']+?)'/g,
    (_m, names, path) => {
      const list = names.split(',').map(s => s.trim()).filter(Boolean)
      const types = list.filter(n => TYPE_ONLY.has(n))
      const values = list.filter(n => !TYPE_ONLY.has(n))
      const parts = []
      if (types.length > 0) {
        parts.push(`import type { ${types.join(', ')} } from '${path}'`)
      }
      if (values.length > 0) {
        parts.push(`import { ${values.join(', ')} } from '${path}'`)
      }
      return parts.length > 0 ? parts.join('\n') : ''
    }
  )
  // 其余相对路径补扩展名
  code = code.replace(/from\s*'(\.[^']+?)'/g, (_m, path) => `from '${path}.ts'`)
  // 系统 SDK 模块改写为本地桩件
  code = code.replace(/from\s*'@kit\.PerformanceAnalysisKit'/g, () => `from '${KIT_STUB}'`)
  const out = resolve(WORK, relDst)
  mkdirSync(dirname(out), { recursive: true })
  writeFileSync(out, code, 'utf-8')
  return out
}

adapt('core/queue/PlayModePolicy.ets', 'core/queue/PlayModePolicy.ts')
adapt('core/queue/PlayQueue.ets', 'core/queue/PlayQueue.ts')
adapt('core/volume/VolumeScale.ets', 'core/volume/VolumeScale.ts')
adapt('persistence/ListPersistence.ets', 'persistence/ListPersistence.ts')
adapt('model/SongList.ets', 'model/SongList.ts')
adapt('model/MusicInfo.ets', 'model/MusicInfo.ts')
adapt('model/AppSettings.ets', 'model/AppSettings.ts')
adapt('lyric/LyricParser.ets', 'lyric/LyricParser.ts')
adapt('utils/LogMask.ets', 'utils/LogMask.ts')
adapt('core/source/MusicMatch.ets', 'core/source/MusicMatch.ts')

const { nextIndex, prevIndex } = await import(`${WORK}/core/queue/PlayModePolicy.ts`)
const { PlayQueue } = await import(`${WORK}/core/queue/PlayQueue.ts`)
const { ListPersistence } = await import(`${WORK}/persistence/ListPersistence.ts`)
const { PreferencesUtil } = await import(`${WORK}/persistence/PreferencesUtil.ts`)
const { DEFAULT_LIST_ID, LOCAL_LIST_ID, LOCAL_LIST_NAME } = await import(`${WORK}/model/SongList.ts`)
const { toPlayerVolume, MAX_VOLUME } = await import(`${WORK}/core/volume/VolumeScale.ts`)
const { LyricParser, isPlaceholderLyric } = await import(`${WORK}/lyric/LyricParser.ts`)
const { maskSensitiveUrl, maskSensitiveText } = await import(`${WORK}/utils/LogMask.ts`)
const { normalizeSongName, normalizeSinger, songMatchKey, bestQualityIndex, pickBetter, topQuality, qualityBadgeText, qualityLevel } =
  await import(`${WORK}/core/source/MusicMatch.ts`)

// ---- 迷你断言框架 ----
let pass = 0
const failures = []
function check(name, actual, expected) {
  const a = JSON.stringify(actual)
  const e = JSON.stringify(expected)
  if (a === e) {
    pass++
  } else {
    failures.push(`${name}\n    期望 ${e}\n    实际 ${a}`)
  }
}
function checkTrue(name, cond) {
  if (cond) {
    pass++
  } else {
    failures.push(name)
  }
}

const m = (id) => ({ id, name: id, singer: 's', source: 'kw', interval: '03:00', meta: {} })
const ids = (arr) => arr.map(x => x.id)

// ============================================================ PlayModePolicy

check('listLoop 下一首：0 → 1', nextIndex('listLoop', 0, 5), 1)
check('listLoop 下一首：末尾回到开头', nextIndex('listLoop', 4, 5), 0)
let randomOk = true
for (let i = 0; i < 200; i++) {
  const idx = nextIndex('listRandom', 2, 5)
  if (idx === 2 || idx < 0 || idx >= 5) {
    randomOk = false
    break
  }
}
checkTrue('listRandom 下一首：200 次抽样均不等于当前且在范围内', randomOk)
check('空队列下一首返回 -1', nextIndex('listLoop', 0, 0), -1)
check('空队列下一首（随机）返回 -1', nextIndex('listRandom', 0, 0), -1)
check('单曲队列下一首返回 0', nextIndex('listLoop', 0, 1), 0)

check('listLoop 上一首：开头回到末尾', prevIndex('listLoop', 0, 5), 4)
check('listLoop 上一首：3 → 2', prevIndex('listLoop', 3, 5), 2)
randomOk = true
for (let i = 0; i < 200; i++) {
  const idx = prevIndex('listRandom', 2, 5)
  if (idx === 2 || idx < 0 || idx >= 5) {
    randomOk = false
    break
  }
}
checkTrue('listRandom 上一首：200 次抽样均不等于当前且在范围内', randomOk)
check('空队列上一首返回 -1', prevIndex('listLoop', 0, 0), -1)
check('单曲队列上一首返回 0', prevIndex('listLoop', 0, 1), 0)

// ============================================================ PlayQueue

{
  const q = new PlayQueue()
  q.setList([m('a'), m('b'), m('c')], 99)
  check('setList 索引越界应钳制到队尾', q.getIndex(), 2)
  q.setList([m('a'), m('b'), m('c')], -5)
  check('setList 负索引应钳制到队首', q.getIndex(), 0)
  q.setList([], 0)
  check('装载空队列后索引为 -1', q.getIndex(), -1)
  check('装载空队列后 size 为 0', q.size, 0)
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b'), m('c'), m('d')], 2)
  const r = q.removeAt(0)
  check('移除非当前曲：removed', r.removed, true)
  check('移除非当前曲：removedCurrent', r.removedCurrent, false)
  check('移除非当前曲：当前索引应前移一位', q.getIndex(), 1)
  check('移除非当前曲：剩余曲目', ids(q.getList()), ['b', 'c', 'd'])
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b'), m('c'), m('d')], 1)
  const r = q.removeAt(1)
  check('移除当前曲：removedCurrent', r.removedCurrent, true)
  check('移除当前曲：接着播放同位置下一曲', r.nextIndex, 1)
  check('移除当前曲：当前曲目变为原下一曲', q.getCurrent().id, 'c')
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b'), m('c')], 2)
  const r = q.removeAt(2)
  check('移除队尾当前曲：接着播放从头', r.nextIndex, 0)
  check('移除队尾当前曲：当前曲目变为队首', q.getCurrent().id, 'a')
}
{
  const q = new PlayQueue()
  q.setList([m('a')], 0)
  const r = q.removeAt(0)
  check('移除唯一曲目：队列清空', q.size, 0)
  check('移除唯一曲目：当前索引 -1', q.getIndex(), -1)
  check('移除唯一曲目：nextIndex -1（无曲可续播）', r.nextIndex, -1)
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b')], 0)
  check('移除越界索引返回 removed=false', q.removeAt(9).removed, false)
  check('移除越界索引不改队列', q.size, 2)
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b'), m('c'), m('d')], 1)
  check('move 当前曲向后：成功', q.move(1, 3), true)
  check('move 当前曲向后：当前索引跟随', q.getIndex(), 3)
  check('move 当前曲向后：队列顺序', ids(q.getList()), ['a', 'c', 'd', 'b'])
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b'), m('c'), m('d')], 1)
  check('move 当前曲向前：成功', q.move(1, 0), true)
  check('move 当前曲向前：当前索引跟随', q.getIndex(), 0)
  check('move 当前曲向前：队列顺序', ids(q.getList()), ['b', 'a', 'c', 'd'])
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b'), m('c'), m('d')], 1)
  check('move 非当前曲且跨过当前曲：当前索引修正', q.move(3, 0) && q.getIndex(), 2)
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b'), m('c')], 0)
  check('move 越界返回 false', q.move(0, 9), false)
  check('move 同位置返回 false', q.move(1, 1), false)
  check('move 越界不改变队列', ids(q.getList()), ['a', 'b', 'c'])
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('c')], 1)
  q.insertAt(1, m('b'))
  check('insertAt 插入到指定位置', ids(q.getList()), ['a', 'b', 'c'])
  check('insertAt 后当前索引顺移', q.getIndex(), 2)
  q.replaceAt(0, m('z'))
  check('replaceAt 替换成功', ids(q.getList()), ['z', 'b', 'c'])
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b'), m('c')], 0)
  q.pushHistory(q.getCurrent())
  q.setIndex(2)
  q.pushHistory(q.getCurrent())
  check('历史栈顶是最近一次', q.peekHistory().id, 'c')
  check('历史歌曲在队列中的索引', q.historyIndexInQueue(), 2)
  check('弹出历史', q.popHistory().id, 'c')
  check('弹出后栈顶变为前一条', q.peekHistory().id, 'a')
  check('indexOfId 找不到返回 -1', q.indexOfId('zzz'), -1)
  q.clearHistory()
  check('清空历史后 peek 为 undefined', q.peekHistory(), undefined)
}
{
  const q = new PlayQueue()
  q.setList([m('a'), m('b')], 1)
  q.clear()
  check('clear 后 size 为 0', q.size, 0)
  check('clear 后索引为 -1', q.getIndex(), -1)
  check('clear 后无当前曲目', q.getCurrent(), undefined)
}

// ============================================================ 歌词解析与占位识别
// 回归点：部分音源查不到歌词时返回「暂无歌词 + 作词/作曲等元信息」的占位文本，
// 若直接当歌词展示，用户会看到一屏元信息却以为已找到歌词。
{
  checkTrue('占位：空文本判为无歌词', isPlaceholderLyric(''))
  checkTrue('占位：纯空白判为无歌词', isPlaceholderLyric('   \n  '))
  checkTrue('占位：「暂无歌词」判为无歌词', isPlaceholderLyric('暂无歌词'))
  checkTrue('占位：「暂无歌词」+元信息判为无歌词',
    isPlaceholderLyric('暂无歌词\n作词: 风起/海来阿木\n作曲: 海来阿木'))
  checkTrue('占位：仅元信息判为无歌词',
    isPlaceholderLyric('作词: 海来阿木\n作曲: 海来阿木\n编曲: 钟强'))
  checkTrue('占位：仅方括号声明判为无歌词',
    isPlaceholderLyric('【未经著作者许可不得翻唱翻录或使用】'))
  checkTrue('正常歌词不被误判为占位',
    !isPlaceholderLyric('[00:01.00]我曾用心爱着你\n[00:05.00]那是因为惹了你'))
  checkTrue('正常歌词（含元信息）不被误判为占位',
    !isPlaceholderLyric('作词: 海来阿木\n[00:01.00]我曾用心爱着你'))

  const lines = LyricParser.parse('[00:01.00]第一行\n[00:05.50]第二行\n[00:09.00]第三行')
  check('歌词解析：行数', lines.length, 3)
  check('歌词解析：首行文本', lines[0].text, '第一行')
  check('歌词解析：次行时间(ms)', lines[1].time, 5500)
  check('歌词解析：空文本返回空数组', LyricParser.parse('').length, 0)
}

// ============================================================ 日志脱敏（凭据不得进入日志）
// 回归点：音源请求日志曾把带 key/token 的完整 URL 写进 hilog 与用户可见的日志面板。
{
  checkTrue('脱敏：URL 的 key 参数被遮蔽',
    maskSensitiveUrl('https://x.com/api?key=secret123&b=2') === 'https://x.com/api?key=***&b=2')
  checkTrue('脱敏：URL 的 token 参数被遮蔽',
    maskSensitiveUrl('https://x.com/api?token=abc&type=json') === 'https://x.com/api?token=***&type=json')
  checkTrue('脱敏：多个敏感参数都被遮蔽',
    maskSensitiveUrl('https://x.com/a?key=k1&secret=s1&sign=sig1') ===
      'https://x.com/a?key=***&secret=***&sign=***')
  checkTrue('脱敏：大小写不敏感',
    maskSensitiveUrl('https://x.com/a?KEY=k1&Token=t1') === 'https://x.com/a?KEY=***&Token=***')
  checkTrue('脱敏：无敏感参数时原样返回',
    maskSensitiveUrl('https://x.com/a?b=2&c=3') === 'https://x.com/a?b=2&c=3')
  checkTrue('脱敏：空串安全',
    maskSensitiveUrl('') === '' && maskSensitiveText('') === '')
  checkTrue('脱敏：音源脚本的 checkUpdate 参数被遮蔽',
    maskSensitiveUrl('https://x.com/script?key=&checkUpdate=5fe365644241ca1b6a0f7ae4e333cf52') ===
      'https://x.com/script?key=***&checkUpdate=***')
  checkTrue('脱敏：JSON 字段值被遮蔽',
    maskSensitiveText('{"key":"abc","name":"x"}') === '{"key":"***","name":"x"}')
  checkTrue('脱敏：JSON 的 token 字段被遮蔽',
    maskSensitiveText('{"token":"t","id":1}') === '{"token":"***","id":1}')
  checkTrue('脱敏：普通 JSON 不受影响',
    maskSensitiveText('{"name":"x","id":1}') === '{"name":"x","id":1}')
}

// ============================================================ 聚合搜索去重（歌名/歌手归一化 + 音质优先）
// 回归点：聚合搜索要合并各音源的同一首歌，归一化不准会漏合并或误合并。
{
  checkTrue('归一化：去掉括号后缀', normalizeSongName('花海 (DJ 阿若版)') === '花海')
  checkTrue('归一化：去掉方括号后缀', normalizeSongName('晴天 [Live]') === '晴天')
  checkTrue('归一化：去掉标点与空格', normalizeSongName('Hello, World!') === 'helloworld')
  checkTrue('归一化：转小写', normalizeSongName('ABC') === 'abc')
  checkTrue('归一化：空串安全', normalizeSongName('') === '')

  checkTrue('归一化：多人歌手拆分排序后一致',
    normalizeSinger('周杰伦/五月天') === normalizeSinger('五月天,周杰伦'))
  checkTrue('归一化：单歌手原样小写', normalizeSinger('周杰伦') === '周杰伦')

  checkTrue('匹配键：同歌同歌手 → 相同 key',
    songMatchKey('花海 (DJ版)', '海来阿木') === songMatchKey('花海', '海来阿木'))
  checkTrue('匹配键：不同歌 → 不同 key',
    songMatchKey('花海', '海来阿木') !== songMatchKey('晴天', '周杰伦'))
  checkTrue('匹配键：同歌不同歌手 → 不同 key',
    songMatchKey('花海', '海来阿木') !== songMatchKey('花海', '周杰伦'))

  checkTrue('音质：flac24bit 最高', bestQualityIndex(['flac24bit', 'flac']) === 0)
  checkTrue('音质：flac 高于 320k', bestQualityIndex(['320k', 'flac']) === 1)
  checkTrue('音质：未知音质按最低档', bestQualityIndex(['128k', 'flac']) === 1)
  checkTrue('音质：空列表按最低档', bestQualityIndex([]) === 4)  // 档位表含 ape
  checkTrue('合并：应保留音质更高的那条',
    pickBetter({ qualitys: ['128k'] }, { qualitys: ['flac'] }) === true)
  checkTrue('合并：音质更低则不替换',
    pickBetter({ qualitys: ['flac'] }, { qualitys: ['128k'] }) === false)
  checkTrue('合并：音质相同则保留先到的',
    pickBetter({ qualitys: ['320k'] }, { qualitys: ['320k'] }) === false)
}

// ============================================================ 音质徽标（对齐 lx-music 的 quality 标签）
{
  checkTrue('最高音质：flac24bit', topQuality(['128k', 'flac24bit', 'flac']) === 'flac24bit')
  checkTrue('最高音质：flac 优于 ape', topQuality(['ape', 'flac']) === 'flac')
  checkTrue('最高音质：320k', topQuality(['128k', '320k']) === '320k')
  checkTrue('最高音质：无有效音质返回空', topQuality(['x', 'y']) === '')
  checkTrue('最高音质：空数组返回空', topQuality([]) === '')

  checkTrue('徽标文案：flac24bit → 无损24', qualityBadgeText('flac24bit') === '无损24')
  checkTrue('徽标文案：flac → 无损', qualityBadgeText('flac') === '无损')
  checkTrue('徽标文案：ape → 无损', qualityBadgeText('ape') === '无损')
  checkTrue('徽标文案：320k → 高品', qualityBadgeText('320k') === '高品')
  checkTrue('徽标文案：128k → 128k', qualityBadgeText('128k') === '128k')
  checkTrue('徽标文案：未知音质 → 空', qualityBadgeText('x') === '')

  checkTrue('档位：flac24bit → lossless24', qualityLevel('flac24bit') === 'lossless24')
  checkTrue('档位：flac → lossless', qualityLevel('flac') === 'lossless')
  checkTrue('档位：320k → high', qualityLevel('320k') === 'high')
  checkTrue('档位：128k → standard', qualityLevel('128k') === 'standard')
  checkTrue('档位：未知 → none', qualityLevel('x') === 'none')
}

// ============================================================ 静态约束：列表点击必须用 onClick
// 回归点：MusicListItem 曾用 gesture(TapGesture()) 触发播放，而它被放在带
// swipeAction 的 ListItem 里，通用手势与 List 的滚动/滑动手势竞争，点击被吞掉
// → 播放列表页「点歌名毫无反应」，播放器仍在放上一首（表现为「点 A 播 B」）。
{
  // 断言只看代码，不看注释（注释里会写明「为什么不能用 TapGesture」）
  const stripComments = (src) => src
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split('\n')
    .map(line => {
      const i = line.indexOf('//')
      return i >= 0 ? line.slice(0, i) : line
    })
    .join('\n')
  const itemCode = stripComments(readFileSync(resolve(SRC, 'components/MusicListItem.ets'), 'utf-8'))
  checkTrue('列表项不得用 TapGesture 触发播放（会被 List 吞掉）', !itemCode.includes('TapGesture'))
  checkTrue('列表项用 onClick 触发播放', /\.onClick\(\(\)\s*=>\s*\{\s*this\.onPlay\(\)/.test(itemCode))
}

// ============================================================ 音量刻度换算
// 回归重点：AVPlayer.setVolume 只接受 0.00–1.00，直接传 0–100 会触发
// errorCode 401「Invalid Parameter: invalid parameters, check volume level」。
{
  check('刻度：0 → 0', toPlayerVolume(0), 0)
  check('刻度：100 → 1（最大音量）', toPlayerVolume(100), 1)
  check('刻度：50 → 0.5', toPlayerVolume(50), 0.5)
  check('刻度：30 → 0.3', toPlayerVolume(30), 0.3)
  check('刻度：1 → 0.01（不得退化为 0 或 1）', toPlayerVolume(1), 0.01)
  check('刻度：越界 150 夹到 1', toPlayerVolume(150), 1)
  check('刻度：越界 -10 夹到 0', toPlayerVolume(-10), 0)
  check('刻度：NaN 兜底为 1', toPlayerVolume(NaN), 1)
  check('刻度：MAX_VOLUME 常量为 100', MAX_VOLUME, 100)
}

// ============================================================ ListPersistence（内置歌单 + 批量落盘）

await ListPersistence.load()

const localSong = {
  id: 'local1', name: '本地曲', singer: 's', source: 'local', interval: '03:00',
  meta: { songId: '', albumName: '', picUrl: null, filePath: '/data/files/local1.mp3', ext: 'mp3' }
}
const onlineSong = {
  id: 'on1', name: '在线曲', singer: 's', source: 'kw', interval: '03:00',
  meta: { songId: 'x', albumName: '', picUrl: null, qualitys: [{ type: '128k', size: '1' }] }
}

{
  // 两个内置歌单都存在、位置固定、名称固定
  const lists = ListPersistence.getLists()
  check('内置歌单：喜欢的音乐存在', ListPersistence.getList(DEFAULT_LIST_ID) != undefined, true)
  check('内置歌单：本地音乐存在', ListPersistence.getList(LOCAL_LIST_ID) != undefined, true)
  check('内置歌单：喜欢的音乐恒居首', lists[0].id, DEFAULT_LIST_ID)
  check('内置歌单：本地音乐居次位', lists[1].id, LOCAL_LIST_ID)
  check('内置歌单：本地音乐名称固定', ListPersistence.getList(LOCAL_LIST_ID).name, LOCAL_LIST_NAME)
  // 不可重命名 / 不可删除
  check('内置歌单：重命名本地音乐被拒绝', await ListPersistence.renameList(LOCAL_LIST_ID, '改名'), false)
  check('内置歌单：重命名喜欢的音乐被拒绝', await ListPersistence.renameList(DEFAULT_LIST_ID, '改名'), false)
  await ListPersistence.removeList(LOCAL_LIST_ID)
  check('内置歌单：删除本地音乐被拒绝', ListPersistence.getList(LOCAL_LIST_ID) != undefined, true)
  await ListPersistence.removeList(DEFAULT_LIST_ID)
  check('内置歌单：删除喜欢的音乐被拒绝', ListPersistence.getList(DEFAULT_LIST_ID) != undefined, true)
}

{
  // 迁移：旧版本把导入的本地歌曲存在 default 里，首次建立「本地音乐」时应复制过来
  await PreferencesUtil.setString('lists_v1', JSON.stringify([
    { id: 'default', name: '喜欢的音乐', list: [localSong, onlineSong], positionUpdateTime: null }
  ]))
  await ListPersistence.load()
  const local = ListPersistence.getList(LOCAL_LIST_ID)
  check('迁移：本地音乐列表被建立', local != undefined, true)
  check('迁移：本地歌曲被复制过来', ids(local.list), ['local1'])
  check('迁移：default 中的歌曲原样保留', ids(ListPersistence.getList(DEFAULT_LIST_ID).list), ['local1', 'on1'])
}

{
  // 连续新建歌单：id 不得碰撞（同一毫秒内 Date.now() 相同）
  const l1 = await ListPersistence.addList('连建A')
  const l2 = await ListPersistence.addList('连建B')
  checkTrue('连续新建歌单：id 不相同', l1.id !== l2.id)
  const l3 = await ListPersistence.addList('连建C')
  checkTrue('连续新建第三个歌单：id 与前两个都不同', l3.id !== l1.id && l3.id !== l2.id)
}
{
  // 批量添加：正常情况全部加入，且整批只落盘一次
  const list = await ListPersistence.addList('队列歌单')
  const before = PreferencesUtil.writes
  const added = await ListPersistence.addMusics(list.id, [m('s1'), m('s2'), m('s3')])
  const writes = PreferencesUtil.writes - before
  check('addMusics：全部加入', added, 3)
  check('addMusics：整批只落盘一次', writes, 1)
  check('addMusics：歌单内容正确', ids(ListPersistence.getList(list.id).list), ['s1', 's2', 's3'])
}
{
  // 去重：同一首歌在队列里出现两次只加一次
  const list = await ListPersistence.addList('去重歌单')
  const added = await ListPersistence.addMusics(list.id, [m('d1'), m('d1'), m('d2')])
  check('addMusics：重复歌曲被去重', added, 2)
  check('addMusics：去重后内容正确', ids(ListPersistence.getList(list.id).list), ['d1', 'd2'])
}
{
  // 空入参不落盘
  const list = await ListPersistence.addList('空歌单')
  const before = PreferencesUtil.writes
  const added = await ListPersistence.addMusics(list.id, [])
  check('addMusics：空数组返回 0', added, 0)
  check('addMusics：空数组不落盘', PreferencesUtil.writes - before, 0)
}
{
  // 歌单不存在返回 0
  const added = await ListPersistence.addMusics('no-such-list', [m('x')])
  check('addMusics：歌单不存在返回 0', added, 0)
}
{
  // 默认歌单（喜欢的音乐）仍在首位
  const lists = ListPersistence.getLists()
  check('默认歌单恒居首', lists[0].id, DEFAULT_LIST_ID)
  checkTrue('新建歌单追加在末尾', lists[lists.length - 1].name === '空歌单')
}

{
  // 同步全量覆盖不应清掉设备本地的「本地音乐」
  await ListPersistence.addMusic(LOCAL_LIST_ID, localSong)
  const before = ids(ListPersistence.getList(LOCAL_LIST_ID).list)
  await ListPersistence.overwriteSyncData([], [{ id: 'list_x', name: '远端歌单', list: [], positionUpdateTime: null }])
  check('同步覆盖：本地音乐被保留', ids(ListPersistence.getList(LOCAL_LIST_ID).list), before)
  check('同步覆盖：喜欢的音乐被远端内容替换', ids(ListPersistence.getList(DEFAULT_LIST_ID).list), [])
  check('同步覆盖：远端用户歌单已建立', ListPersistence.getList('list_x') != undefined, true)
}

// ============================================================ 结果
console.log(`\n通过 ${pass} 项`)
if (failures.length > 0) {
  console.log(`失败 ${failures.length} 项：`)
  for (const f of failures) console.log('  ✗ ' + f)
  rmSync(WORK, { recursive: true, force: true })
  process.exit(1)
} else {
  console.log('全部通过 ✓')
  rmSync(WORK, { recursive: true, force: true })
}
