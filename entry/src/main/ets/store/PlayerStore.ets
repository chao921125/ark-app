/**
 * 播放仓库 — 对齐上游 `src/store/player` + `src/core/init/player`（快照恢复）
 *
 * 【模块边界】本模块只做**持久化**：记录快照、音源覆盖偏好。
 * 它不驱动播放器、不反查播放器状态 —— 需要的上下文（当前索引、进度、设置开关）
 * 由编排层（app/PlayerFacade）以参数传入，因此 store/ 与 player/ 之间不存在循环引用。
 */
import { PreferencesUtil } from '../persistence/PreferencesUtil'
import { ListPersistence } from '../persistence/ListPersistence'
import { MusicInfo } from '../model/MusicInfo'
import { DEFAULT_LIST_ID } from '../model/SongList'

const KEY_SNAPSHOT = 'play_snapshot_v1'
const KEY_SOURCE_OVERRIDES = 'source_overrides_v1'

export interface PlaySnapshot {
  listId: string
  index: number
  /** 暂停时的进度（秒）；旧版本快照可能缺失 */
  position: number
}

/** 快照恢复后可直接装载播放队列的目标信息 */
export interface RestoredTarget {
  listId: string
  index: number
  position: number
  musics: MusicInfo[]
  music: MusicInfo
}

class PlayerStoreImpl {
  private snapshotListId: string = DEFAULT_LIST_ID

  getSnapshotListId(): string {
    return this.snapshotListId
  }

  setSnapshotListId(id: string): void {
    this.snapshotListId = id
  }

  /**
   * 保存播放快照。切歌 / 暂停时由编排层调用。
   * @param listId  当前播放所属的歌单 id
   * @param index   当前曲目在队列中的索引（<0 表示无当前曲目，忽略本次保存）
   * @param position 当前进度（秒）
   */
  async saveSnapshot(listId: string, index: number, position: number): Promise<void> {
    if (index < 0) {
      return
    }
    this.snapshotListId = listId
    const snapshot: PlaySnapshot = {
      listId: listId,
      index: index,
      position: Math.max(position, 0)
    }
    try {
      await PreferencesUtil.setString(KEY_SNAPSHOT, JSON.stringify(snapshot))
    } catch (ignored) {
      // 持久化失败不影响播放
    }
  }

  /** 读取原始快照 */
  async loadSnapshot(): Promise<PlaySnapshot | null> {
    let json = ''
    try {
      json = await PreferencesUtil.getString(KEY_SNAPSHOT)
    } catch (ignored) {
      // ignore
    }
    if (json.length == 0) {
      return null
    }
    try {
      return JSON.parse(json) as PlaySnapshot
    } catch (e) {
      // 快照损坏则忽略
      return null
    }
  }

  /**
   * 启动恢复：解析出可装载的队列与曲目（**不自动播放**）。
   * @param restoreProgress 是否恢复上次进度（由编排层按设置项传入）
   */
  async restore(restoreProgress: boolean): Promise<RestoredTarget | null> {
    const snapshot: PlaySnapshot | null = await this.loadSnapshot()
    if (snapshot == null) {
      return null
    }
    try {
      const lists = ListPersistence.getLists()
      let target = lists.find(l => l.id == snapshot.listId)
      if (target == undefined) {
        target = lists.length > 0 ? lists[0] : undefined
      }
      if (target == undefined || target.list.length == 0) {
        return null
      }
      const idx = Math.min(Math.max(snapshot.index, 0), target.list.length - 1)
      this.snapshotListId = target.id
      const music = target.list[idx]
      const pos = typeof snapshot.position === 'number' && restoreProgress ? snapshot.position : 0
      const result: RestoredTarget = {
        listId: target.id,
        index: idx,
        position: pos,
        musics: target.list.slice(),
        music: music
      }
      return result
    } catch (e) {
      // 快照损坏则忽略
      return null
    }
  }

  // ---- 音源覆盖（换源播放持久化） ----

  /** 获取某首歌的音源覆盖设置 */
  async getSourceOverride(songId: string): Promise<string | undefined> {
    let json = ''
    try {
      json = await PreferencesUtil.getString(KEY_SOURCE_OVERRIDES)
    } catch (ignored) {
      // ignore
    }
    if (json.length == 0) {
      return undefined
    }
    try {
      const overrides = JSON.parse(json) as Record<string, string>
      return overrides[songId]
    } catch (ignored) {
      return undefined
    }
  }

  /** 设置某首歌的音源覆盖（换源播放时调用） */
  async setSourceOverride(songId: string, sourceId: string): Promise<void> {
    let json = ''
    try {
      json = await PreferencesUtil.getString(KEY_SOURCE_OVERRIDES)
    } catch (ignored) {
      // ignore
    }
    let overrides: Record<string, string> = {}
    if (json.length > 0) {
      try {
        overrides = JSON.parse(json) as Record<string, string>
      } catch (ignored) {
        overrides = {}
      }
    }
    overrides[songId] = sourceId
    try {
      await PreferencesUtil.setString(KEY_SOURCE_OVERRIDES, JSON.stringify(overrides))
    } catch (ignored) {
      // ignore
    }
  }

  /** 移除某首歌的音源覆盖 */
  async removeSourceOverride(songId: string): Promise<void> {
    let json = ''
    try {
      json = await PreferencesUtil.getString(KEY_SOURCE_OVERRIDES)
    } catch (ignored) {
      return
    }
    if (json.length == 0) {
      return
    }
    try {
      const overrides = JSON.parse(json) as Record<string, string>
      if (overrides[songId] != undefined) {
        const rest: Record<string, string> = {}
        const keys = Object.keys(overrides)
        for (let i = 0; i < keys.length; i++) {
          const key = keys[i]
          if (key != songId) {
            rest[key] = overrides[key]
          }
        }
        await PreferencesUtil.setString(KEY_SOURCE_OVERRIDES, JSON.stringify(rest))
      }
    } catch (ignored) {
      // ignore
    }
  }
}

export const PlayerStore: PlayerStoreImpl = new PlayerStoreImpl()
