/**
 * 歌单持久化 — 对齐上游 `src/core/list.ts`（KV + JSON 序列化存储列表集合）
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PreferencesUtil } from './PreferencesUtil'
import {
  SongList,
  newList,
  DEFAULT_LIST_ID,
  DEFAULT_LIST_NAME,
  LOCAL_LIST_ID,
  LOCAL_LIST_NAME,
  BUILTIN_LIST_IDS,
  isBuiltinList
} from '../model/SongList'
import { MusicInfo, isLocalInfo } from '../model/MusicInfo'
import { AddMusicLocationType } from '../model/AppSettings'

const TAG = 'ListPersistence'
const DOMAIN = 0x0001
const KEY_LISTS = 'lists_v1'
const KEY_LAST_LIST = 'last_list_id_v1'

class ListPersistenceImpl {
  private lists: SongList[] = []

  async load(): Promise<SongList[]> {
    let json = ''
    try {
      json = await PreferencesUtil.getString(KEY_LISTS)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'load lists failed: %{public}s', JSON.stringify(e))
    }
    if (json.length > 0) {
      try {
        this.lists = JSON.parse(json) as SongList[]
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'parse lists failed: %{public}s', JSON.stringify(e))
        this.lists = []
      }
    }
    if (this.lists.length == 0) {
      this.lists = [newList(DEFAULT_LIST_ID, DEFAULT_LIST_NAME)]
      await this.save()
    }
    await this.ensureBuiltinLists()
    return this.lists
  }

  /**
   * 保证两个内置歌单存在且名称固定：
   *   - 「喜欢的音乐」（default）：收藏落点
   *   - 「本地音乐」：本地导入落点
   * 旧版本把导入的本地歌曲也存在 default 里，因此「本地音乐」首次建立时
   * 把 default 中的本地歌曲**复制**一份过来（复制而非移动：收藏关系不丢）。
   */
  private async ensureBuiltinLists(): Promise<void> {
    let changed: boolean = false
    const def = this.getList(DEFAULT_LIST_ID)
    if (def == undefined) {
      this.lists.unshift(newList(DEFAULT_LIST_ID, DEFAULT_LIST_NAME))
      changed = true
    } else if (def.name != DEFAULT_LIST_NAME) {
      def.name = DEFAULT_LIST_NAME
      changed = true
    }

    const local = this.getList(LOCAL_LIST_ID)
    if (local == undefined) {
      const created = newList(LOCAL_LIST_ID, LOCAL_LIST_NAME)
      if (def != undefined) {
        for (let i = 0; i < def.list.length; i++) {
          const music: MusicInfo = def.list[i]
          if (isLocalInfo(music.meta)) {
            created.list.push(music)
          }
        }
      }
      this.lists.splice(1, 0, created)
      changed = true
      hilog.info(DOMAIN, TAG, 'created builtin local list, migrated %{public}d local songs', created.list.length)
    } else if (local.name != LOCAL_LIST_NAME) {
      local.name = LOCAL_LIST_NAME
      changed = true
    }

    if (changed) {
      await this.save()
    }
  }

  getLists(): SongList[] {
    return this.lists
  }

  async save(): Promise<void> {
    try {
      await PreferencesUtil.setString(KEY_LISTS, JSON.stringify(this.lists))
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save lists failed: %{public}s', JSON.stringify(e))
    }
  }

  async saveLastListId(id: string): Promise<void> {
    await PreferencesUtil.setString(KEY_LAST_LIST, id)
  }

  async loadLastListId(): Promise<string> {
    const id = await PreferencesUtil.getString(KEY_LAST_LIST)
    return id.length > 0 ? id : DEFAULT_LIST_ID
  }

  getList(id: string): SongList | undefined {
    return this.lists.find(l => l.id == id)
  }

  /**
   * 添加歌曲到歌单。
   * @param location 插入位置（对齐上游 list.addMusicLocationType）：'top' 顶部 / 'bottom' 底部
   * @returns 是否成功添加（重复歌曲返回 false）
   */
  async addMusic(listId: string, music: MusicInfo, location: AddMusicLocationType = 'bottom'): Promise<boolean> {
    const list = this.getList(listId)
    if (list == undefined) {
      return false
    }
    if (list.list.some(m => m.id == music.id)) {
      return false
    }
    if (location == 'top') {
      list.list.unshift(music)
    } else {
      list.list.push(music)
    }
    await this.save()
    return true
  }

  /**
   * 批量添加歌曲到指定歌单（按 id 去重）。
   * 与逐首调用 addMusic 的区别：整批只落盘一次 —— 保存播放队列为歌单时
   * 队列可能有上百首，逐首保存会造成上百次 Preferences flush。
   * @returns 实际新增的歌曲数
   */
  async addMusics(listId: string, musics: MusicInfo[]): Promise<number> {
    const list = this.getList(listId)
    if (list == undefined || musics.length == 0) {
      return 0
    }
    let added: number = 0
    for (let i = 0; i < musics.length; i++) {
      const music: MusicInfo = musics[i]
      if (list.list.some(m => m.id == music.id)) {
        continue
      }
      list.list.push(music)
      added++
    }
    if (added > 0) {
      await this.save()
    }
    return added
  }

  async removeMusic(listId: string, musicId: string): Promise<void> {
    const list = this.getList(listId)
    if (list == undefined) {
      return
    }
    list.list = list.list.filter(m => m.id != musicId)
    await this.save()
  }

  async clearList(listId: string): Promise<void> {
    const list = this.getList(listId)
    if (list == undefined) {
      return
    }
    list.list = []
    await this.save()
  }

  async addList(name: string): Promise<SongList> {
    const list = newList(this.genListId(), name)
    this.lists.push(list)
    await this.save()
    return list
  }

  /**
   * 生成不与现有歌单冲突的 id。
   *
   * 不能只用 Date.now()：同一毫秒内连续新建两个歌单会得到相同 id，
   * 后建的会把先建的顶掉（歌单内容混在一起）。这里加随机后缀并做冲突检查。
   */
  private genListId(): string {
    let id: string = ''
    for (let i = 0; i < 16; i++) {
      id = `list_${Date.now()}_${Math.floor(Math.random() * 1000000)}`
      if (this.getList(id) == undefined) {
        return id
      }
    }
    // 极端情况下退化为带计数器的时间戳
    return `list_${Date.now()}_${this.lists.length}`
  }

  async renameList(id: string, name: string): Promise<boolean> {
    // 内置歌单（喜欢的音乐 / 本地音乐）名称固定，不可重命名
    if (isBuiltinList(id)) {
      return false
    }
    const list = this.getList(id)
    const trimmed = name.trim()
    if (list == undefined || trimmed.length == 0) {
      return false
    }
    list.name = trimmed
    await this.save()
    return true
  }

  async removeList(id: string): Promise<void> {
    if (isBuiltinList(id)) {
      return
    }
    this.lists = this.lists.filter(l => l.id != id)
    await this.save()
  }

  // ---- 喜欢的音乐（对齐上游 likeList：收藏 = 加入 default 列表）----

  /** 收藏/列表数据变化版本号：UI @Watch 刷新（复用 likeListRev 键，MyListView/SearchView 已监听） */
  private notifyDataChanged(): void {
    const rev = AppStorage.get<number>('likeListRev') ?? 0
    AppStorage.setOrCreate<number>('likeListRev', rev + 1)
  }

  /** 歌曲是否已收藏（存在于"喜欢的音乐"列表） */
  isLiked(musicId: string): boolean {
    const def = this.getList(DEFAULT_LIST_ID)
    return def != undefined && def.list.some(m => m.id == musicId)
  }

  /**
   * 切换收藏（对齐上游 toggleLike）：
   * 已收藏 → 从"喜欢的音乐"移除并返回 false；未收藏 → 加入并返回 true。
   */
  async toggleLike(music: MusicInfo): Promise<boolean> {
    if (this.isLiked(music.id)) {
      await this.removeMusic(DEFAULT_LIST_ID, music.id)
      this.notifyDataChanged()
      return false
    }
    const added: boolean = await this.addMusic(DEFAULT_LIST_ID, music)
    if (!added) {
      // 写入失败（歌单不存在等）必须暴露出来：
      // 以前这里无视 addMusic 的返回值直接返回 true，
      // 结果是提示「已加入喜欢的音乐」而列表里根本没有 —— 用户无从判断出了什么问题。
      throw new Error('收藏失败：未能写入「喜欢的音乐」')
    }
    this.notifyDataChanged()
    return true
  }

  // ---- PC 同步（对齐上游 list_data_overwrite / list_create / list_update_position 等 action）----

  /**
   * 同步全量覆盖：default 列表替换、非 default 歌单整体重建（default 恒居首）。
   * 对齐上游 list_data_overwrite(isRemote) 语义（合并模式时远端已 merge 完成为全量数据）。
   *
   * 「本地音乐」是设备本地的文件库，不参与同步，**保留**不被覆盖。
   */
  async overwriteSyncData(defaultMusics: MusicInfo[], userLists: SongList[]): Promise<void> {
    const newDef = newList(DEFAULT_LIST_ID, DEFAULT_LIST_NAME)
    newDef.list = defaultMusics.slice()
    const ordered: SongList[] = [newDef]
    const local = this.getList(LOCAL_LIST_ID)
    if (local != undefined) {
      ordered.push(local)
    }
    for (let i = 0; i < userLists.length; i++) {
      if (isBuiltinList(userLists[i].id)) {
        continue
      }
      ordered.push(userLists[i])
    }
    this.lists = ordered
    await this.save()
    this.notifyDataChanged()
  }

  /** 在指定位置创建歌单（list_create；id 可选保留远端 id；位置收窄到内置歌单之后） */
  async addListAt(position: number, name: string, id?: string): Promise<SongList> {
    const listId = id != undefined && id.length > 0 ? id : this.genListId()
    const list = newList(listId, name.trim().length > 0 ? name.trim() : '未命名歌单')
    const insertAt = Math.min(Math.max(position, BUILTIN_LIST_IDS.length), this.lists.length)
    this.lists.splice(insertAt, 0, list)
    await this.save()
    this.notifyDataChanged()
    return list
  }

  /** 用户歌单重排序（list_update_position：ids 顺序即新顺序；内置歌单恒居首） */
  async reorderUserLists(ids: Array<string>): Promise<void> {
    const def = this.getList(DEFAULT_LIST_ID)
    const defList = def != undefined ? def : newList(DEFAULT_LIST_ID, DEFAULT_LIST_NAME)
    const local = this.getList(LOCAL_LIST_ID)
    const localList = local != undefined ? local : newList(LOCAL_LIST_ID, LOCAL_LIST_NAME)
    const byId = new Map<string, SongList>()
    for (let i = 0; i < this.lists.length; i++) {
      if (!isBuiltinList(this.lists[i].id)) {
        byId.set(this.lists[i].id, this.lists[i])
      }
    }
    const ordered: SongList[] = [defList, localList]
    for (let i = 0; i < ids.length; i++) {
      const found = byId.get(ids[i])
      if (found != undefined) {
        ordered.push(found)
        byId.delete(ids[i])
      }
    }
    // 远端未提及的歌单保持原相对顺序追加
    const rest = Array.from(byId.values())
    for (let i = 0; i < rest.length; i++) {
      ordered.push(rest[i])
    }
    this.lists = ordered
    await this.save()
    this.notifyDataChanged()
  }

  /** 覆盖指定歌单的歌曲内容（list_music_overwrite；不 save，调用方批量后统一 save） */
  overwriteListMusic(listId: string, musics: MusicInfo[]): void {
    const list = this.getList(listId)
    if (list == undefined) {
      return
    }
    list.list = musics.slice()
  }

  /** 同步动作批量处理完成后统一通知 UI 刷新（复用 likeListRev，MyListView/SearchView 已监听） */
  notifySyncChanged(): void {
    this.notifyDataChanged()
  }
}

export const ListPersistence: ListPersistenceImpl = new ListPersistenceImpl()