/**
 * PC 同步列表数据桥接 — 对齐上游 `src/plugins/sync/listEvent.ts`
 *  - getLocalListData：本地歌单 → LX.Sync.List.ListData（defaultList=喜欢的音乐；loveList 固定空，见已知限制）
 *  - setLocalListData：远端全量数据 → 覆盖本地（对应上游 list_data_overwrite）
 *  - handleRemoteListAction：远端增量 action 应用到本地（V1 支持核心动作子集）
 * 注意：远端 MusicInfo 多出的字段（lrc/alias 等）在本工程解析时忽略，不影响播放。
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { MusicInfo } from '../model/MusicInfo'
import { ListPersistence } from '../persistence/ListPersistence'
import { SongList, DEFAULT_LIST_ID, isBuiltinList } from '../model/SongList'

const TAG = 'SyncListData'
const DOMAIN = 0x0001

/** 对齐上游 LX.List.UserListInfoFull（source/sourceListId 本工程无第三方来源，固定空） */
export interface SyncUserListInfo {
  id: string
  name: string
  source: string
  sourceListId: string
  locationUpdateTime: number | null
  list: MusicInfo[]
}

/** 对齐上游 LX.Sync.List.ListData */
export interface SyncListData {
  defaultList: MusicInfo[]
  loveList: MusicInfo[]
  userList: SyncUserListInfo[]
}

/** 对齐上游 LX.Sync.List.ActionList */
export interface SyncListAction {
  action: string
  data: ESObject
}

function emptyUserListInfo(id: string, name: string): SyncUserListInfo {
  const info: SyncUserListInfo = {
    id: id,
    name: name,
    source: '',
    sourceListId: '',
    locationUpdateTime: null,
    list: []
  }
  return info
}

export class SyncListDataOps {
  /**
   * 本地 → 同步数据形状
   *
   * 只上行「喜欢的音乐」（default）与用户歌单；「本地音乐」是设备本地的文件库
   * （文件路径指向本机沙箱），同步到桌面端无意义，因此不参与上行。
   */
  static getLocalListData(): SyncListData {
    const lists = ListPersistence.getLists()
    const def = ListPersistence.getList(DEFAULT_LIST_ID)
    const userList: SyncUserListInfo[] = []
    for (let i = 0; i < lists.length; i++) {
      const l = lists[i]
      if (isBuiltinList(l.id)) {
        continue
      }
      const info: SyncUserListInfo = {
        id: l.id,
        name: l.name,
        source: '',
        sourceListId: '',
        locationUpdateTime: l.positionUpdateTime,
        list: l.list.slice()
      }
      userList.push(info)
    }
    const data: SyncListData = {
      defaultList: def != undefined ? def.list.slice() : [],
      loveList: [],
      userList: userList
    }
    return data
  }

  /** 远端全量数据 → 覆盖本地（对齐上游 list_data_overwrite(isRemote=true)） */
  static async setLocalListData(data: SyncListData): Promise<void> {
    const userLists: SongList[] = []
    const remoteUsers = data.userList != undefined ? data.userList : []
    for (let i = 0; i < remoteUsers.length; i++) {
      const u = remoteUsers[i]
      const list: SongList = {
        id: u.id,
        name: u.name,
        list: u.list != undefined ? u.list : [],
        positionUpdateTime: u.locationUpdateTime != undefined ? u.locationUpdateTime : null
      }
      userLists.push(list)
    }
    await ListPersistence.overwriteSyncData(data.defaultList != undefined ? data.defaultList : [], userLists)
  }

  /** 远端增量 action → 本地（对齐上游 handleRemoteListAction） */
  static async handleRemoteListAction(action: SyncListAction): Promise<void> {
    switch (action.action) {
      case 'list_data_overwrite':
        await SyncListDataOps.setLocalListData(action.data as SyncListData)
        break
      case 'list_create': {
        const d = action.data as SyncCreateData
        const infos = d.listInfos != undefined ? d.listInfos : []
        let position = d.position != undefined ? d.position : 0
        for (let i = 0; i < infos.length; i++) {
          const info = infos[i]
          await ListPersistence.addListAt(position, info.name != undefined ? info.name : '未命名歌单', info.id)
          position++
        }
        break
      }
      case 'list_remove': {
        const ids = action.data as Array<string>
        if (ids != undefined) {
          for (let i = 0; i < ids.length; i++) {
            await ListPersistence.removeList(ids[i])
          }
        }
        break
      }
      case 'list_update': {
        const lists = action.data as SyncUserListInfo[]
        if (lists != undefined) {
          for (let i = 0; i < lists.length; i++) {
            await ListPersistence.renameList(lists[i].id, lists[i].name)
          }
        }
        break
      }
      case 'list_update_position': {
        const d = action.data as SyncUpdatePositionData
        if (d.ids != undefined) {
          ListPersistence.reorderUserLists(d.ids)
        }
        break
      }
      case 'list_music_add': {
        const d = action.data as SyncMusicAddData
        const musics = d.musicInfos != undefined ? d.musicInfos : []
        for (let i = 0; i < musics.length; i++) {
          await ListPersistence.addMusic(d.id, musics[i])
        }
        break
      }
      case 'list_music_remove': {
        const d = action.data as SyncMusicRemoveData
        const ids = d.ids != undefined ? d.ids : []
        for (let i = 0; i < ids.length; i++) {
          await ListPersistence.removeMusic(d.listId, ids[i])
        }
        break
      }
      case 'list_music_clear': {
        const ids = action.data as Array<string>
        if (ids != undefined) {
          for (let i = 0; i < ids.length; i++) {
            await ListPersistence.clearList(ids[i])
          }
        }
        break
      }
      case 'list_music_overwrite': {
        const d = action.data as SyncMusicOverwriteData
        ListPersistence.overwriteListMusic(d.listId, d.musicInfos != undefined ? d.musicInfos : [])
        break
      }
      case 'list_music_move':
      case 'list_music_update':
      case 'list_music_update_position':
        hilog.warn(DOMAIN, TAG, 'sync action %{public}s not supported (v1)', action.action)
        break
      default:
        hilog.warn(DOMAIN, TAG, 'unknown list sync action: %{public}s', action.action)
        break
    }
  }
}

/** list_create data：{ position, listInfos } */
interface SyncCreateData {
  position?: number
  listInfos?: SyncUserListInfo[]
}

/** list_update_position data：{ position, ids } */
interface SyncUpdatePositionData {
  position?: number
  ids?: Array<string>
}

/** list_music_add data：{ id, musicInfos, addMusicLocationType } */
interface SyncMusicAddData {
  id: string
  musicInfos?: MusicInfo[]
  addMusicLocationType?: string
}

/** list_music_remove data：{ listId, ids } */
interface SyncMusicRemoveData {
  listId: string
  ids?: Array<string>
}

/** list_music_overwrite data：{ listId, musicInfos } */
interface SyncMusicOverwriteData {
  listId: string
  musicInfos?: MusicInfo[]
}

export { emptyUserListInfo }