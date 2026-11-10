/**
 * 主页 — 对齐上游 `src/screens/Home/index.tsx` + `src/navigation/registerScreens.tsx`
 * 结构：内容区（播放列表/搜索/设置）+ 迷你播放条 + 自定义底栏；播放详情以全屏覆盖层呈现；
 * 悬浮歌词条覆盖在最上层（可在设置/播放详情开关）。
 */
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { MyListView } from './MyListView'
import { SearchView } from './SearchView'
import { SettingView } from './SettingView'
import { PlayDetail } from './PlayDetail'
import { PlayerBar } from '../components/PlayerBar'
import { FloatLyricBar } from '../components/FloatLyricBar'
import { SourceSandboxHost } from '../components/SourceSandboxHost'
import { ListStore } from '../store/ListStore'

@Entry
@Component
struct Index {
  @State currentTab: number = 0
  @StorageLink('showPlayDetail') showPlayDetail: boolean = false

  /** 返回键：先收起播放详情；开启退出确认时二次确认 */
  onBackPress(): boolean {
    if (this.showPlayDetail) {
      this.showPlayDetail = false
      return true
    }
    if (ListStore.getSettings().exitConfirmation) {
      promptAction.showDialog({
        title: '退出应用',
        message: '确定退出CC音乐吗？',
        buttons: [
          { text: '取消', color: $r('app.color.text_secondary') },
          { text: '退出', color: $r('app.color.theme_primary') }
        ]
      }).then((result: promptAction.ShowDialogSuccessResponse) => {
        if (result.index == 1) {
          const context = getContext(this) as common.UIAbilityContext
          context.terminateSelf()
        }
      }).catch(() => {
        // 对话框取消则留在应用
      })
      return true
    }
    return false
  }

  build() {
    Stack() {
      // 自定义音源脚本宿主（1x1 隐藏 Web，置于最底层保持 JS 运行）
      SourceSandboxHost()

      Column() {
        Column() {
          if (this.currentTab == 0) {
            MyListView()
          } else if (this.currentTab == 1) {
            SearchView()
          } else {
            SettingView()
          }
        }
        .layoutWeight(1)

        PlayerBar()

        // 自定义底栏
        Row() {
          this.tabItem(0, '播放列表', '♪')
          this.tabItem(1, '搜索', '🔍')
          this.tabItem(2, '设置', '⚙')
        }
        .width('100%')
        .height(52)
        .backgroundColor($r('app.color.bg_card'))
        .border({ width: { top: 0.5 }, color: $r('app.color.divider') })
      }
      .width('100%')
      .height('100%')

      if (this.showPlayDetail) {
        PlayDetail()
      }

      // 悬浮歌词条（覆盖层，含播放详情之上）
      FloatLyricBar()
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  tabItem(index: number, label: string, icon: string) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(18)
        .fontColor(this.currentTab == index ? $r('app.color.theme_primary') : $r('app.color.text_secondary'))
      Text(label)
        .fontSize(11)
        .fontColor(this.currentTab == index ? $r('app.color.theme_primary') : $r('app.color.text_secondary'))
    }
    .width('33.3%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentTab = index
    })
  }
}
