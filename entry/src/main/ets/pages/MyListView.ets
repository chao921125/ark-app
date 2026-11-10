/**
 * 播放列表页 — 对齐上游 `src/screens/Home/Views/Mylist`（多歌单管理）
 *
 * 顶部为两个并排分区按钮：本地列表 / 喜欢列表，点击切换下方内容区。
 *  - 本地列表：导入到本机的音频；顶部提供黑色「导入音乐」按钮
 *  - 喜欢列表：「喜欢的音乐」中收藏的歌曲
 *
 * 本页不再提供歌单的新建/重命名/清空/删除等管理入口（多歌单能力已从本页移除）。
 */
import { common } from '@kit.AbilityKit'

import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { MusicInfo } from '../model/MusicInfo'
import { ListPersistence } from '../persistence/ListPersistence'
import { PlayerFacade } from '../app/PlayerFacade'
import { FileScanner } from '../utils/FileScanner'
import { MusicListItem } from '../components/MusicListItem'
import { DEFAULT_LIST_ID, LOCAL_LIST_ID } from '../model/SongList'
import { AppSettings, DEFAULT_SETTINGS } from '../model/AppSettings'
import { ListStore } from '../store/ListStore'

const TAG: string = 'MyListView'
const DOMAIN: number = 0x0001

/** 页面顶部的两个分区 */
export type ListSection = 'local' | 'like'

@Component
export struct MyListView {
  /** 当前选中的分区 */
  @State section: ListSection = 'local'
  @State musics: MusicInfo[] = []
  @State settings: AppSettings = DEFAULT_SETTINGS
  @StorageLink('playIndex') playIndex: number = -1
  /** 当前播放曲目 id：高亮按 id 判定（playIndex 是队列内索引，与本列表索引未必一致） */
  @StorageLink('currentMusicId') currentMusicId: string = ''
  // 歌单内容变化（收藏、导入、队列另存为歌单等）时刷新
  @StorageLink('likeListRev') @Watch('refreshList') likeListRev: number = 0
  @State importing: boolean = false

  aboutToAppear(): void {
    this.settings = ListStore.getSettings()
    this.refreshList()
  }

  /** 当前分区对应的歌单：喜欢列表指向「喜欢的音乐」，本地列表指向「本地音乐」 */
  private displayListId(): string {
    return this.section == 'like' ? DEFAULT_LIST_ID : LOCAL_LIST_ID
  }

  private refreshList(): void {
    const list = ListPersistence.getList(this.displayListId())
    this.musics = list != undefined ? list.list.slice() : []
  }

  /** 切换分区：内容区需要按新分区重新取数 */
  private switchSection(section: ListSection): void {
    if (this.section == section) {
      return
    }
    this.section = section
    this.refreshList()
  }

  /** 导入本地音频到「本地音乐」 */
  private async importMusic(): Promise<void> {
    if (this.importing) {
      return
    }
    const context = getContext(this) as common.UIAbilityContext
    this.importing = true
    try {
      const uris = await FileScanner.pickAudioFiles(context)
      if (uris.length == 0) {
        return
      }
      const imported = await FileScanner.importAudio(uris)
      for (let i = 0; i < imported.length; i++) {
        await ListPersistence.addMusic(LOCAL_LIST_ID, imported[i], this.settings.addMusicLocationType)
      }
      this.refreshList()
      promptAction.showToast({ message: `已导入 ${imported.length} 首歌曲`, duration: 2000 })
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'import music failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '导入失败，请重试', duration: 2000 })
    } finally {
      this.importing = false
    }
  }

  private async removeMusic(music: MusicInfo): Promise<void> {
    try {
      await ListPersistence.removeMusic(this.displayListId(), music.id)
      this.refreshList()
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'remove music failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '删除失败，请重试', duration: 1800 })
    }
  }

  private async playAt(index: number): Promise<void> {
    try {
      await PlayerFacade.playFromList(this.displayListId(), this.musics, index)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'play at failed: %{public}s', JSON.stringify(e))
      promptAction.showToast({ message: '播放失败，请重试', duration: 1800 })
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部两个并排分区按钮（选中项高亮）
        Row({ space: 8 }) {
          this.sectionButton('local', '本地列表')
          this.sectionButton('like', '喜欢列表')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        if (this.section == 'local') {
          // 导入音乐：与本地列表结合的黑色按钮
          Button(this.importing ? '导入中…' : '导入音乐')
            .width('92%')
            .height(44)
            .fontSize(15)
            .type(ButtonType.Capsule)
            .backgroundColor($r('app.color.btn_dark_bg'))
            .fontColor($r('app.color.btn_dark_fg'))
            .enabled(!this.importing)
            .margin({ bottom: 10 })
            .onClick(() => {
              void this.importMusic()
            })
        }

        this.musicListArea()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))
    }
    .width('100%')
    .height('100%')
  }

  /** 顶部分区按钮：两个按钮样式一致，选中项用主题色高亮 */
  @Builder
  sectionButton(id: ListSection, label: string) {
    Text(label)
      .fontSize(14)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .padding({ top: 8, bottom: 8 })
      .borderRadius(16)
      .backgroundColor(this.section == id ? $r('app.color.theme_primary') : $r('app.color.bg_card'))
      .fontColor(this.section == id ? Color.White : $r('app.color.text_primary'))
      .onClick(() => {
        this.switchSection(id)
      })
  }

  /** 歌曲列表区（两个分区共用） */
  @Builder
  musicListArea() {
    if (this.musics.length == 0) {
      Column({ space: 10 }) {
        Text('♪')
          .fontSize(48)
          .fontColor($r('app.color.divider'))
        Text(this.section == 'like' ? '还没有喜欢的歌曲' : '还没有本地音乐')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
        Text(this.section == 'like'
          ? '在任意歌曲上点击 ♥ 即可收藏到这里'
          : '点击上方【导入音乐】导入本地音频，\n支持 mp3 / flac / wav / m4a / aac / ogg / ape / wma，可多选')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 2 }) {
        ForEach(this.musics, (music: MusicInfo, index: number) => {
          ListItem() {
            MusicListItem({
              music: music,
              active: music.id == this.currentMusicId,
              liked: ListPersistence.isLiked(music.id),
              showInterval: this.settings.showInterval,
              showAlbumName: this.settings.showAlbumName,
              onPlay: () => {
                void this.playAt(index)
              },
              onRemove: () => {
                void this.removeMusic(music)
              },
              onToggleLike: () => {
                void ListPersistence.toggleLike(music)
              }
            })
          }
          .swipeAction({
            end: () => {
              this.deleteCell(music)
            }
          })
        }, (music: MusicInfo) => `${music.id}_${ListPersistence.isLiked(music.id)}`)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 8, right: 8 })
      .scrollBar(BarState.Auto)
    }
  }

  @Builder
  deleteCell(music: MusicInfo) {
    Button() {
      Image($r('app.media.ic_delete'))
        .width(20)
        .height(20)
        .fillColor(Color.White)
    }
    .width(52)
    .height('100%')
    .type(ButtonType.Normal)
    .borderRadius(8)
    .backgroundColor('#E05454')
    .onClick(() => {
      void this.removeMusic(music)
    })
  }
}
