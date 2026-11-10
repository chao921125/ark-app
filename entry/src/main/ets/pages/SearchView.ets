/**
 * 搜索页 — 对齐上游 `src/screens/Home/Views/Search/index.tsx`（在线源：KW/WY/KG/TX/MG）
 * 结构：源切换（酷我/网易云/酷狗/QQ音乐/咪咕）→ 搜索栏（输入框 + 搜索按钮）→ 结果列表
 * （歌名/歌手/专辑/时长 + 加入歌单 + 点击播放）。
 * 加入歌单支持选择目标歌单（弹层内可新建）。
 * 状态：加载态 / 空态 / 结果态；网络错误 toast 提示并保留上一次列表（场景 5 降级）。
 */
import { promptAction } from '@kit.ArkUI'
import { KeyCode } from '@kit.InputKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MusicInfo, MusicInfoMetaOnline } from '../model/MusicInfo'
import { SourceResolver } from '../core/source/SourceResolver'
import { ListPersistence } from '../persistence/ListPersistence'
import { PlayerFacade } from '../app/PlayerFacade'
import { SongList, LOCAL_LIST_ID } from '../model/SongList'
import { AppSettings, DEFAULT_SETTINGS } from '../model/AppSettings'
import { ListStore } from '../store/ListStore'
import { SearchHistory } from '../persistence/SearchHistory'
import { MusicBadges } from '../components/MusicBadges'

const TAG = 'SearchView'
const DOMAIN = 0x0001

/** 搜索结果队列 id（playFromList 用，与持久化歌单区分；kw/wy/kg/tx/mg 共用） */
const SEARCH_LIST_ID = 'search_online'

interface SourceChip {
  id: string
  label: string
}

/** 联想建议条数上限 */
const SUGGEST_LIMIT: number = 8
/** 联想防抖间隔（毫秒） */
const SUGGEST_DEBOUNCE: number = 300

/** 内置热门搜索词（对齐上游 search.isShowHotSearch） */
const HOT_SEARCH_WORDS: string[] = ['周杰伦', '林俊杰', '陈奕迅', '薛之谦', '邓紫棋', '海阔天空', '起风了', '晴天']

const SOURCE_CHIPS: SourceChip[] = [
  { id: 'kw', label: 'KW' },
  { id: 'wy', label: 'WY' },
  { id: 'kg', label: 'KG' },
  { id: 'tx', label: 'TX' },
  { id: 'mg', label: 'MG' }
]

/** 聚合搜索：并行查所有内置音源并合并去重 */
const ALL_SOURCE_ID: string = 'all'
const ALL_SOURCE_LABEL: string = '聚合'

@Component
export struct SearchView {
  @State keyword: string = ''
  /** 当前搜索源：默认聚合（并行查所有内置音源并合并去重） */
  @State source: string = ALL_SOURCE_ID
  @State results: MusicInfo[] = []
  @State loading: boolean = false
  @State searched: boolean = false
  // 搜索历史 / 热门搜索（对齐上游 search.isShowHistorySearch / isShowHotSearch）
  @State history: string[] = []
  @State settings: AppSettings = DEFAULT_SETTINGS
  // 搜索联想建议（在线 tip search，失败时降级到本地曲库匹配）
  @State suggestions: string[] = []
  @State suggestIndex: number = -1
  @State showSuggestions: boolean = false
  @State suggesting: boolean = false
  private suggestTimer: number = -1
  /** 输入框控制器：搜索后用它收起输入法（stopEditing），否则键盘会遮挡结果列表 */
  private inputController: TextInputController = new TextInputController()
  /** 联想请求序号：只采纳最后一次请求的结果，避免慢响应覆盖新输入 */
  private suggestSeq: number = 0
  /**
   * 采纳建议后抑制下一轮联想：
   * 采纳会把建议词写回输入框 → 触发 onChange → 又去取一次联想，
   * 联想列表会把刚搜出来的结果盖住。置位后由 onChange 消费掉。
   */
  private suppressNextSuggest: boolean = false
  @StorageLink('playIndex') playIndex: number = -1
  /** 当前播放曲目 id：高亮按 id 判定（队列与搜索结果不是同一份数据，索引不可比） */
  @StorageLink('currentMusicId') currentMusicId: string = ''
  @StorageLink('likeListRev') likeListRev: number = 0
  // 加入歌单弹层
  @State showPicker: boolean = false
  @State pickerLists: SongList[] = []
  @State pickerCreating: boolean = false
  @State pickerNewName: string = ''
  private pickerMusic: MusicInfo | undefined = undefined

  aboutToAppear(): void {
    this.settings = ListStore.getSettings()
    void this.loadHistory()
  }

  /** 页面销毁时撤掉待触发的防抖定时器，避免组件已销毁还去 setState */
  aboutToDisappear(): void {
    if (this.suggestTimer != -1) {
      clearTimeout(this.suggestTimer)
      this.suggestTimer = -1
    }
  }

  private async loadHistory(): Promise<void> {
    try {
      this.history = await SearchHistory.get()
    } catch (e) {
      // 读历史失败不该影响搜索：降级成空列表即可
      hilog.warn(DOMAIN, TAG, 'load search history failed: %{public}s', JSON.stringify(e))
      this.history = []
    }
  }

  /** 点击历史/热门词 → 直接搜索 */
  private async searchBy(word: string): Promise<void> {
    this.keyword = word
    try {
      await this.doSearch()
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'search by word failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '搜索失败，请重试', duration: 1800 })
    }
  }

  // ---- 搜索联想建议 ----

  /**
   * 输入变化 → 300ms 防抖后再计算建议。
   * 防抖是为了避免每敲一个字就全量扫一遍曲库。
   */
  private scheduleSuggest(): void {
    if (this.suggestTimer != -1) {
      clearTimeout(this.suggestTimer)
      this.suggestTimer = -1
    }
    const kw: string = this.keyword.trim()
    if (kw.length === 0) {
      this.closeSuggest()
      return
    }
    this.suggestTimer = setTimeout(() => {
      this.suggestTimer = -1
      void this.requestSuggest(kw)
    }, SUGGEST_DEBOUNCE)
  }

  /**
   * 取在线联想词（tip search）：调当前音源的联想接口。
   * 失败或无结果时降级到本地曲库匹配，保证输入总有反馈。
   */
  private async requestSuggest(kw: string): Promise<void> {
    const seq: number = ++this.suggestSeq
    this.suggesting = true
    let words: string[] = []
    const resolver = SourceResolver.getInstance()
    try {
      // 聚合模式：并发取各音源的联想词并合并（语义与「聚合搜索」一致）
      words = this.source == ALL_SOURCE_ID
        ? await resolver.suggestAll(kw, resolver.getSearchableSources())
        : await resolver.suggest(this.source, kw)
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'online suggest failed: %{public}s', JSON.stringify(e))
      words = []
    }
    if (seq != this.suggestSeq) {
      // 期间已有更新的输入，丢弃本次过期结果
      return
    }
    this.suggesting = false
    if (words.length === 0) {
      words = this.localSuggest(kw)
    }
    // 去重：ForEach 的 key 只能用候选词本身，重复会导致节点复用异常
    const unique: string[] = []
    const seen: Set<string> = new Set()
    for (let i = 0; i < words.length; i++) {
      const w: string = words[i]
      if (w.length === 0 || seen.has(w)) {
        continue
      }
      seen.add(w)
      unique.push(w)
    }
    this.suggestions = unique.slice(0, SUGGEST_LIMIT)
    this.suggestIndex = this.suggestions.length > 0 ? 0 : -1
    this.showSuggestions = true
  }

  /** 降级路径：在本地曲库（喜欢/本地列表）里按歌名、歌手、曲目 id 匹配 */
  private localSuggest(kw: string): string[] {
    const lower: string = kw.toLowerCase()
    const pool: string[] = []
    const seen: Set<string> = new Set()
    const collect: (m: MusicInfo) => void = (m: MusicInfo) => {
      if (seen.has(m.id)) {
        return
      }
      const hit: boolean = m.name.toLowerCase().indexOf(lower) >= 0 ||
        m.singer.toLowerCase().indexOf(lower) >= 0 ||
        m.id.toLowerCase().indexOf(lower) >= 0
      if (!hit) {
        return
      }
      seen.add(m.id)
      pool.push(m.singer.length > 0 ? `${m.name} - ${m.singer}` : m.name)
    }
    for (let i = 0; i < this.results.length; i++) {
      collect(this.results[i])
    }
    const lists: SongList[] = ListPersistence.getLists()
    for (let i = 0; i < lists.length; i++) {
      const songs: MusicInfo[] = lists[i].list
      for (let j = 0; j < songs.length; j++) {
        collect(songs[j])
      }
    }
    return pool
  }

  private closeSuggest(): void {
    // 必须一并撤掉待触发的防抖定时器：否则「关闭建议」之后定时器又把建议弹回来，
    // 表现为搜索完成后建议列表又出现、且点建议只会触发搜索而不会播放
    if (this.suggestTimer != -1) {
      clearTimeout(this.suggestTimer)
      this.suggestTimer = -1
    }
    this.suggestSeq++
    this.suggesting = false
    this.suggestions = []
    this.suggestIndex = -1
    this.showSuggestions = false
  }

  /** 采纳某条建议：填入关键词并直接搜索 */
  private async applySuggest(index: number): Promise<void> {
    const word: string = this.suggestions[index]
    if (word == undefined || word.length === 0) {
      return
    }
    this.suppressNextSuggest = true
    this.keyword = word
    this.closeSuggest()
    try {
      await this.doSearch()
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'apply suggest failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '搜索失败，请重试', duration: 1800 })
    }
  }

  /** 搜索框键盘事件：↑↓ 选择、回车确认、Esc 关闭 */
  private onSearchKey(event: KeyEvent): void {
    if (!this.showSuggestions || this.suggestions.length === 0) {
      return
    }
    if (event.type !== KeyType.Down) {
      return
    }
    if (event.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
      this.suggestIndex = (this.suggestIndex + 1) % this.suggestions.length
      event.stopPropagation()
    } else if (event.keyCode === KeyCode.KEYCODE_DPAD_UP) {
      this.suggestIndex = (this.suggestIndex - 1 + this.suggestions.length) % this.suggestions.length
      event.stopPropagation()
    } else if (event.keyCode === KeyCode.KEYCODE_ENTER) {
      event.stopPropagation()
      void this.applySuggest(this.suggestIndex >= 0 ? this.suggestIndex : 0)
    } else if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
      this.closeSuggest()
    }
  }

  /**
   * 收起输入法。
   *
   * 点「搜索」后焦点仍在输入框上，键盘不会自己收起，会把搜索结果挡掉一半。
   * 这里用 TextInputController.stopEditing() 主动收起（回车提交时输入法虽会自行收起，
   * 再调一次也无害）。
   */
  private hideKeyboard(): void {
    try {
      this.inputController.stopEditing()
    } catch (e) {
      // 收起失败不影响搜索本身
      hilog.warn(DOMAIN, TAG, 'hide keyboard failed: %{public}s', JSON.stringify(e))
    }
  }

  private async doSearch(): Promise<void> {
    // 先收起键盘，再判断是否有内容：键盘收起后结果区立刻恢复全高，不用等搜索结束。
    // 放在判空之前，是为了让「点了搜索但没输入」也能收起键盘（用户是在结束输入状态）。
    this.hideKeyboard()
    const kw = this.keyword.trim()
    if (kw.length == 0 || this.loading) {
      return
    }
    this.loading = true
    try {
      const resolver = SourceResolver.getInstance()
      const list: MusicInfo[] = this.source == ALL_SOURCE_ID
        ? await resolver.searchAll(kw, resolver.getSearchableSources())
        : await resolver.search(this.source, kw)
      this.results = list
      this.searched = true
      // 记录搜索历史（对齐上游 search.isShowHistorySearch）
      await SearchHistory.add(kw)
      await this.loadHistory()
      if (list.length == 0) {
        promptAction.showToast({ message: '未找到相关歌曲', duration: 2000 })
      }
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'search failed: %{public}s', JSON.stringify(err))
      // 场景 5：错误提示且保留上一次列表
      promptAction.showToast({ message: `搜索失败：${err.message ?? '网络异常'}`, duration: 2000 })
    } finally {
      this.loading = false
    }
  }

  /**
   * 点击某首歌：播放队列里**只放这一首**（不是整个搜索结果）。
   * 想连续听整个搜索结果请用「播放全部」。
   */
  private async playAt(index: number): Promise<void> {
    const music = this.results[index]
    if (music == undefined) {
      return
    }
    try {
      await PlayerFacade.playFromList(SEARCH_LIST_ID, [music], 0)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'play at failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '播放失败，请重试', duration: 1800 })
    }
  }

  /** 播放全部：把整个搜索结果作为播放队列，从第一首开始 */
  private async playAll(): Promise<void> {
    if (this.results.length == 0) {
      return
    }
    try {
      await PlayerFacade.playFromList(SEARCH_LIST_ID, this.results.slice(), 0)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'play all failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '播放失败，请重试', duration: 1800 })
    }
  }

  /** 收藏/取消收藏（对齐上游 likeList：写入/移出"喜欢的音乐"） */
  private async toggleLike(music: MusicInfo): Promise<void> {
    try {
      const liked = await ListPersistence.toggleLike(music)
      promptAction.showToast({ message: liked ? '已加入喜欢的音乐' : '已取消收藏', duration: 1500 })
    } catch (e) {
      // 收藏写入失败必须让用户知道，否则「点了没反应」会被当成功能坏了
      hilog.error(DOMAIN, TAG, 'toggle like failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '收藏操作失败，请重试', duration: 1800 })
    }
  }

  private openPicker(music: MusicInfo): void {
    this.pickerMusic = music
    // 「本地音乐」是设备本地的文件库，不作为在线歌曲的加入目标
    this.pickerLists = ListPersistence.getLists().filter(l => l.id != LOCAL_LIST_ID)
    this.pickerCreating = false
    this.pickerNewName = ''
    this.showPicker = true
  }

  private async addToList(list: SongList): Promise<void> {
    const music = this.pickerMusic
    if (music == undefined) {
      return
    }
    try {
      const exists = list.list.some(m => m.id == music.id)
      if (exists) {
        // TC-07：重复添加去重提示
        promptAction.showToast({ message: `已在「${list.name}」中`, duration: 2000 })
        this.showPicker = false
        return
      }
      const ok = await ListPersistence.addMusic(list.id, music, this.settings.addMusicLocationType)
      this.showPicker = false
      promptAction.showToast({ message: ok ? `已加入「${list.name}」` : '加入失败', duration: 2000 })
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'addToList failed: %{public}s', JSON.stringify(err))
      promptAction.showToast({ message: '加入失败', duration: 2000 })
    }
  }

  private async createAndAdd(): Promise<void> {
    const music = this.pickerMusic
    const name = this.pickerNewName.trim()
    if (music == undefined || name.length == 0) {
      promptAction.showToast({ message: '请输入歌单名', duration: 1500 })
      return
    }
    try {
      const created = await ListPersistence.addList(name)
      await ListPersistence.addMusic(created.id, music)
      this.showPicker = false
      promptAction.showToast({ message: `已创建「${created.name}」并加入`, duration: 2000 })
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'createAndAdd failed: %{public}s', JSON.stringify(err))
      promptAction.showToast({ message: '创建失败', duration: 2000 })
    }
  }

  /** 行副标题：歌手 · 专辑 */
  private rowSubtitle(music: MusicInfo): string {
    if (!this.settings.showAlbumName) {
      return music.singer.length > 0 ? music.singer : '未知歌手'
    }
    const meta = music.meta as MusicInfoMetaOnline
    const album = meta.albumName.length > 0 ? meta.albumName : ''
    if (music.singer.length > 0 && album.length > 0) {
      return `${music.singer} · ${album}`
    }
    return music.singer.length > 0 ? music.singer : album
  }

  /** 一组可点击的词条（热门/历史） */
  @Builder
  wordSection(title: string, words: string[], onTap: (word: string) => void) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ left: 16, top: 6 })
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(words, (word: string) => {
          Text(word)
            .fontSize(13)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(15)
            .backgroundColor($r('app.color.bg_card'))
            .fontColor($r('app.color.text_primary'))
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              onTap(word)
            })
        }, (word: string) => word)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
  }

  /** 联想建议列表：含空状态提示，支持点击采纳与键盘上下选择 */
  @Builder
  suggestionArea() {
    if (this.suggesting && this.suggestions.length == 0) {
      Column({ space: 10 }) {
        LoadingProgress()
          .width(30)
          .height(30)
          .color($r('app.color.theme_primary'))
        Text('正在获取联想词…')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.suggestions.length == 0) {
      Column({ space: 8 }) {
        Text('🔍')
          .fontSize(36)
        Text('没有匹配的联想词')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        Text('换个关键词，或直接回车搜索在线歌曲')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 2 }) {
        ForEach(this.suggestions, (word: string, index: number) => {
          ListItem() {
            Row({ space: 10 }) {
              Text(index == this.suggestIndex ? '›' : '　')
                .fontSize(16)
                .fontColor($r('app.color.theme_primary'))
                .width(14)
              Text(word)
                .fontSize(15)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({ left: 8, right: 12, top: 11, bottom: 11 })
            .backgroundColor(index == this.suggestIndex ? $r('app.color.bg_card') : Color.Transparent)
            .borderRadius(8)
            .onClick(() => {
              void this.applySuggest(index)
            })
          }
        }, (word: string) => word)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 8, right: 8 })
      .scrollBar(BarState.Auto)
    }
  }

  private sourceLabel(id: string): string {
    if (id == ALL_SOURCE_ID) {
      return ALL_SOURCE_LABEL
    }
    const chip = SOURCE_CHIPS.find(c => c.id == id)
    return chip != undefined ? chip.label : id
  }

  /**
   * 下拉选项：value 即显示文本（ArkUI 的 SelectOption 只有 value，没有 label）。
   * 下标 0 是聚合，其余按 SOURCE_CHIPS 顺序，用 sourceIdAt 反查源 id。
   */
  private sourceOptions(): SelectOption[] {
    const opts: SelectOption[] = [{ value: ALL_SOURCE_LABEL }]
    for (let i = 0; i < SOURCE_CHIPS.length; i++) {
      opts.push({ value: SOURCE_CHIPS[i].label })
    }
    return opts
  }

  /** 由下拉项下标还原源 id */
  private sourceIdAt(index: number): string {
    if (index <= 0) {
      return ALL_SOURCE_ID
    }
    const chip: SourceChip | undefined = SOURCE_CHIPS[index - 1]
    return chip != undefined ? chip.id : ALL_SOURCE_ID
  }

  build() {
    Stack() {
      Column() {
        // 音源选择（下拉）+ 播放全部
        Row({ space: 8 }) {
          Select(this.sourceOptions())
            .value(this.sourceLabel(this.source))
            .height(32)
            .width(116)
            .backgroundColor($r('app.color.bg_card'))
            .onSelect((index: number, value: string) => {
              const next: string = this.sourceIdAt(index)
              if (this.source != next) {
                this.source = next
                // 切换源**不**触发联想：联想只在用户输入时出现。
                // 这里只收起当前联想，等用户继续输入再按新源取。
                this.closeSuggest()
              }
            })

          // 「播放全部」：把整个搜索结果作为队列播放
          Blank()
          Button(this.loading ? '搜索中…' : '播放全部')
            .height(28)
            .fontSize(12)
            .type(ButtonType.Capsule)
            .backgroundColor($r('app.color.theme_primary'))
            .fontColor(Color.White)
            .flexShrink(0)
            .enabled(!this.loading && this.results.length > 0)
            .onClick(() => {
              void this.playAll()
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 0 })

        // 搜索栏
        Row({ space: 8 }) {
          TextInput({ placeholder: `搜索在线歌曲（${this.sourceLabel(this.source)}）`, text: this.keyword,
            controller: this.inputController })
            .height(36)
            .layoutWeight(1)
            .fontSize(14)
            .backgroundColor($r('app.color.bg_card'))
            .onChange((value: string) => {
              this.keyword = value
              if (this.suppressNextSuggest) {
                // 采纳建议引起的回填，不再触发联想
                this.suppressNextSuggest = false
                return
              }
              this.scheduleSuggest()
            })
            .onKeyEvent((event: KeyEvent) => {
              this.onSearchKey(event)
            })
            .onSubmit(() => {
              this.closeSuggest()
              void this.doSearch()
            })
          Button(this.loading ? '搜索中…' : '搜索')
            .height(36)
            .fontSize(13)
            .type(ButtonType.Capsule)
            .backgroundColor($r('app.color.theme_primary'))
            .enabled(!this.loading)
            .onClick(() => {
              this.closeSuggest()
              // 点按钮时焦点仍在输入框上，键盘不会自行收起 —— 这里主动收，
              // 否则键盘会一直遮着搜索结果
              this.hideKeyboard()
              void this.doSearch()
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        // 热门搜索 / 历史搜索（未输入关键词且尚未搜索时展示）
        if (this.keyword.trim().length == 0 && !this.searched) {
          if (this.settings.showHotSearch) {
            this.wordSection('热门搜索', HOT_SEARCH_WORDS, (word: string) => {
              void this.searchBy(word)
            })
          }
          if (this.settings.showHistorySearch && this.history.length > 0) {
            this.wordSection('搜索历史', this.history, (word: string) => {
              void this.searchBy(word)
            })
          }
        }

        // 内容区：联想建议 / 加载态 / 空态 / 结果列表
        if (this.showSuggestions) {
          this.suggestionArea()
        } else if (this.loading && this.results.length == 0) {
          Column({ space: 12 }) {
            LoadingProgress()
              .width(36)
              .height(36)
              .color($r('app.color.theme_primary'))
            Text('正在搜索…')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.searched && this.results.length == 0) {
          Column({ space: 12 }) {
            Text('🔍')
              .fontSize(40)
            Text('未找到相关歌曲')
              .fontSize(15)
              .fontColor($r('app.color.text_secondary'))
            Text('换个关键词试试吧')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.results.length > 0) {
          List({ space: 2 }) {
            ForEach(this.results, (music: MusicInfo, index: number) => {
              ListItem() {
                Row({ space: 10 }) {
                  // 播放指示
                  Text(music.id == this.currentMusicId ? '♪' : '')
                    .fontSize(16)
                    .fontColor($r('app.color.theme_primary'))
                    .width(24)
                    .textAlign(TextAlign.Center)

                  // 歌名/副标题区域：点击播放
                  Column({ space: 3 }) {
                    Text(music.name)
                      .fontSize(15)
                      .fontColor(this.playIndex == index ? $r('app.color.theme_primary') : $r('app.color.text_primary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    // 副标题行：音质/来源徽标 + 歌手·专辑（对齐上游 OnlineList/ListItem）
                    Row({ space: 8 }) {
                      MusicBadges({ music: music, showSource: this.source == ALL_SOURCE_ID })
                      Text(this.rowSubtitle(music))
                        .fontSize(12)
                        .fontColor($r('app.color.text_secondary'))
                        .layoutWeight(1)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .width('100%')
                    .alignItems(VerticalAlign.Center)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .onClick(() => {
                    void this.playAt(index)
                  })

                  // 收藏（对齐上游 likeList）
                  // 【区分】已收藏 = 实心红心，未收藏 = 空心灰心。
                  // 之前未收藏用 divider 色(#E5E5E5)，白底上几乎看不见，
                  // 导致「哪首喜欢过、哪首没喜欢」分辨不出来。
                  Text(ListPersistence.isLiked(music.id) ? '♥' : '♡')
                    .fontSize(16)
                    .fontColor(ListPersistence.isLiked(music.id) ? '#E05454' : $r('app.color.text_secondary'))
                    .onClick(() => {
                      void this.toggleLike(music)
                    })

                  Text(music.interval ?? '--:--')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))

                  Button('加入歌单')
                    .height(26)
                    .fontSize(11)
                    .type(ButtonType.Capsule)
                    .backgroundColor($r('app.color.theme_primary'))
                    .onClick(() => {
                      this.openPicker(music)
                    })
                }
                .width('100%')
                .padding({ left: 8, right: 12, top: 10, bottom: 10 })
                .borderRadius(8)
                .backgroundColor($r('app.color.bg_card'))
              }
            }, (music: MusicInfo) => `${music.id}_${ListPersistence.isLiked(music.id)}_${this.likeListRev}`)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 8, right: 8 })
          .scrollBar(BarState.Auto)
        } else {
          // 初始态：未搜索
          Column({ space: 12 }) {
            Text('♪')
              .fontSize(48)
              .fontColor($r('app.color.divider'))
            Text('输入关键词搜索在线歌曲')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))

      // 加入歌单弹层（选择目标歌单 / 新建歌单并加入）
      if (this.showPicker) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => {
              this.showPicker = false
            })
          Column({ space: 10 }) {
            Text('加入歌单')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            if (this.pickerCreating) {
              TextInput({ placeholder: '新歌单名称', text: this.pickerNewName })
                .height(38)
                .fontSize(14)
                .backgroundColor($r('app.color.bg_page'))
                .onChange((value: string) => {
                  this.pickerNewName = value
                })
                .onSubmit(() => {
                  void this.createAndAdd()
                })
              Row({ space: 10 }) {
                Button('返回选择')
                  .layoutWeight(1)
                  .height(36)
                  .fontSize(13)
                  .type(ButtonType.Capsule)
                  .backgroundColor($r('app.color.bg_page'))
                  .fontColor($r('app.color.text_secondary'))
                  .onClick(() => {
                    this.pickerCreating = false
                  })
                Button('创建并加入')
                  .layoutWeight(1)
                  .height(36)
                  .fontSize(13)
                  .type(ButtonType.Capsule)
                  .backgroundColor($r('app.color.theme_primary'))
                  .fontColor(Color.White)
                  .onClick(() => {
                    void this.createAndAdd()
                  })
              }
              .width('100%')
            } else {
              List({ space: 4 }) {
                ForEach(this.pickerLists, (list: SongList) => {
                  ListItem() {
                    Row() {
                      Text(list.name)
                        .fontSize(14)
                        .fontColor($r('app.color.text_primary'))
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Blank()
                      Text(`${list.list.length} 首`)
                        .fontSize(12)
                        .fontColor($r('app.color.text_secondary'))
                    }
                    .width('100%')
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .borderRadius(8)
                    .backgroundColor($r('app.color.bg_page'))
                    .onClick(() => {
                      void this.addToList(list)
                    })
                  }
                }, (list: SongList) => list.id)
              }
              .width('100%')
              .height(190)
              .scrollBar(BarState.Auto)

              Text('＋ 新建歌单并加入')
                .fontSize(13)
                .fontColor($r('app.color.theme_primary'))
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 8, bottom: 4 })
                .onClick(() => {
                  this.pickerCreating = true
                  this.pickerNewName = ''
                })
            }
          }
          .width('80%')
          .padding(18)
          .borderRadius(14)
          .backgroundColor($r('app.color.bg_card'))
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
