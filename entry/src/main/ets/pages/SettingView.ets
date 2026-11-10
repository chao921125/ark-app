/**
 * 设置页 — 对齐上游 `src/screens/Home/Views/Setting`（分区式 + 抽屉导航）
 *
 * 结构：顶部标题行（可点击打开抽屉，右侧显示当前分区）+ 内容区；
 * 分区导航收进左侧抽屉，纵向排列，点击切换分区并收起抽屉。
 *
 * 【为什么自绘抽屉】本工程 SDK 未提供 bindDrawer / bindSideSheet，
 * Panel 组件是底部半模态而非侧边抽屉，因此用 Stack + translate 动画自绘，
 * 可控性更好（宽度、遮罩透明度、选中态样式都能按项目规范定制）。
 */
import { BasicSection } from './setting/BasicSection'
import { PlayerSection } from './setting/PlayerSection'
import { LyricSection } from './setting/LyricSection'
import { ListSection } from './setting/ListSection'
import { SearchSection } from './setting/SearchSection'
import { SyncSection } from './setting/SyncSection'
import { BackupSection } from './setting/BackupSection'
import { OtherSection } from './setting/OtherSection'
import { AboutSection } from './setting/AboutSection'

/** 分区定义（id 与上游 SETTING_SCREENS 对应，去掉本项目不适用的 version） */
interface SettingTab {
  id: string
  label: string
}

/** 抽屉宽度占屏宽比例（用百分比而非固定 vp，适配不同屏宽） */
const DRAWER_WIDTH: string = '70%'

@Component
export struct SettingView {
  /** 当前选中的分区 */
  @State activeTab: string = 'basic'
  /** 抽屉是否展开 */
  @State drawerOpen: boolean = false

  private tabs: SettingTab[] = [
    { id: 'basic', label: '基本设置' },
    { id: 'player', label: '播放设置' },
    { id: 'lyric', label: '歌词设置' },
    { id: 'list', label: '列表设置' },
    { id: 'search', label: '搜索设置' },
    { id: 'sync', label: '数据同步' },
    { id: 'backup', label: '备份与恢复' },
    { id: 'other', label: '其它' },
    { id: 'about', label: '关于' }
  ]

  /** 当前分区名（标题行右侧显示） */
  private activeLabel(): string {
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].id == this.activeTab) {
        return this.tabs[i].label
      }
    }
    return '设置'
  }

  /** 选择分区并收起抽屉 */
  private selectTab(id: string): void {
    this.activeTab = id
    this.drawerOpen = false
  }

  build() {
    Stack() {
      Column() {
        // 标题行：整行可点击，打开抽屉（右侧显示当前分区 + 箭头提示）
        Row() {
          Text('设置')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text(this.activeLabel())
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
          Text('›')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 4 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 10 })
        .onClick(() => {
          this.drawerOpen = !this.drawerOpen
        })

        // 内容区
        Scroll() {
          Column({ space: 16 }) {
            if (this.activeTab == 'basic') {
              BasicSection()
            } else if (this.activeTab == 'player') {
              PlayerSection()
            } else if (this.activeTab == 'lyric') {
              LyricSection()
            } else if (this.activeTab == 'list') {
              ListSection()
            } else if (this.activeTab == 'search') {
              SearchSection()
            } else if (this.activeTab == 'sync') {
              SyncSection()
            } else if (this.activeTab == 'backup') {
              BackupSection()
            } else if (this.activeTab == 'other') {
              OtherSection()
            } else {
              AboutSection()
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 4, bottom: 24 })
        }
        .scrollBar(BarState.Auto)
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.bg_page'))

      // 抽屉遮罩（点击收起）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.45)')
        .opacity(this.drawerOpen ? 1 : 0)
        .hitTestBehavior(this.drawerOpen ? HitTestMode.Default : HitTestMode.None)
        .animation({ duration: 200, curve: Curve.EaseInOut })
        .onClick(() => {
          this.drawerOpen = false
        })

      // 抽屉：纵向分区列表
      Column() {
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
          .padding({ left: 20, right: 20, top: 20, bottom: 12 })

        Divider()
          .color($r('app.color.divider'))
          .height(1)
          .margin({ bottom: 8 })

        Scroll() {
          Column({ space: 2 }) {
            ForEach(this.tabs, (tab: SettingTab) => {
              this.drawerItem(tab)
            }, (tab: SettingTab) => tab.id)
          }
          .width('100%')
          .padding({ left: 8, right: 8, bottom: 20 })
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .width('100%')
      }
      .width(DRAWER_WIDTH)
      .height('100%')
      .backgroundColor($r('app.color.bg_card'))
      // 收起时按自身宽度的 100% 左移，恰好完全移出屏幕
      .translate({ x: this.drawerOpen ? 0 : '-100%' })
      .hitTestBehavior(this.drawerOpen ? HitTestMode.Default : HitTestMode.None)
      .animation({ duration: 200, curve: Curve.EaseInOut })
    }
    .width('100%')
    .height('100%')
    // Stack 默认居中对齐会让抽屉跑到屏幕中间，这里统一贴左上角
    .alignContent(Alignment.TopStart)
  }

  /** 抽屉里的一个分区项：选中项高亮（主题色文字 + 左侧指示条） */
  @Builder
  drawerItem(tab: SettingTab) {
    Row() {
      Row()
        .width(3)
        .height(18)
        .borderRadius(2)
        .backgroundColor(this.activeTab == tab.id ? $r('app.color.theme_primary') : Color.Transparent)
        .margin({ right: 10 })
      Text(tab.label)
        .fontSize(15)
        .fontWeight(this.activeTab == tab.id ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.activeTab == tab.id ? $r('app.color.theme_primary') : $r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13, right: 12 })
    .borderRadius(8)
    .backgroundColor(this.activeTab == tab.id ? $r('app.color.bg_page') : Color.Transparent)
    .onClick(() => {
      this.selectTab(tab.id)
    })
  }
}
