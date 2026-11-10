/**
 * 基本设置分区 — 对齐上游 `Setting/settings/Basic`
 *
 * 含本项目特色：自定义音源脚本管理。
 */
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppSettings, DEFAULT_SETTINGS, cloneSettings, ThemeMode } from '../../model/AppSettings'
import { ListStore } from '../../store/ListStore'
import { SourceEngine } from '../../core/source/SourceEngine'
import { SourceInfo, SupportedSource } from '../../core/source/LxTypes'
import { FileScanner } from '../../utils/FileScanner'
import { SettingOptionSheet } from '../../components/setting/SettingOptionSheet'
import {
  SettingSectionTitle,
  SettingSwitchRow,
  SettingRadioRow,
  SettingDivider,
  SettingActionRow,
  SettingHint
} from '../../components/setting/SettingWidgets'

/** 自定义音源状态（数据来自 SourceEngine） */
interface SourceEngineState {
  inited: boolean
  error: string
  meta: SourceInfo | undefined
  allSources: SourceInfo[]
  loadedId: string
  sourceIds: string[]
  sources: SupportedSource[]
}

function getSourceEngineState(): SourceEngineState {
  const engine = SourceEngine.getInstance()
  const list = engine.listSources()
  const loadedId = engine.getLoadedSourceId()
  const supported = engine.getSupportedSources()
  const ids = Object.keys(supported)
  const srcList: SupportedSource[] = []
  for (let i = 0; i < ids.length; i++) {
    const s = supported[ids[i]]
    if (s != undefined) {
      srcList.push(s)
    }
  }
  let loadedMeta: SourceInfo | undefined = undefined
  for (let i = 0; i < list.length; i++) {
    if (list[i].id == loadedId) {
      loadedMeta = list[i]
      break
    }
  }
  return {
    inited: engine.isInited(),
    error: '',
    meta: loadedMeta,
    allSources: list,
    loadedId: loadedId,
    sourceIds: ids,
    sources: srcList
  }
}

@Component
export struct BasicSection {
  @State settings: AppSettings = DEFAULT_SETTINGS
  @State userApiState: SourceEngineState = getSourceEngineState()
  @State importingScript: boolean = false
  @State userApiUrl: string = ''
  @State showThemeSheet: boolean = false

  private themeOptions: string[] = ['跟随系统', '浅色', '深色']

  aboutToAppear(): void {
    this.settings = ListStore.getSettings()
    this.refreshUserApiState()
  }

  private update(patch: (s: AppSettings) => void): void {
    const next: AppSettings = cloneSettings(this.settings)
    patch(next)
    ListStore.applySettings(next)
    this.settings = next
  }

  private themeLabel(): string {
    if (this.settings.themeMode == 'light') {
      return '浅色'
    }
    if (this.settings.themeMode == 'dark') {
      return '深色'
    }
    return '跟随系统'
  }

  refreshUserApiState(): void {
    this.userApiState = getSourceEngineState()
  }

  // ---- 自定义音源脚本 ----

  private async importUserApi(): Promise<void> {
    if (this.importingScript) {
      return
    }
    const context = getContext(this) as common.UIAbilityContext
    this.importingScript = true
    try {
      const uri = await FileScanner.pickUserScript(context)
      if (uri.length == 0) {
        return
      }
      let code = ''
      try {
        code = await FileScanner.readTextFromUri(uri)
      } catch (e) {
        promptAction.showToast({ message: `读取脚本失败：${(e as BusinessError).message ?? '未知错误'}`, duration: 3000 })
        return
      }
      try {
        const info = SourceEngine.getInstance().importSource(code)
        await SourceEngine.getInstance().loadSource(info.id)
        this.refreshUserApiState()
        promptAction.showToast({ message: `「${info.name}」已导入并加载`, duration: 2500 })
      } catch (e) {
        this.refreshUserApiState()
        promptAction.showToast({ message: `导入失败：${(e as BusinessError).message ?? '未知错误'}`, duration: 3000 })
      }
    } finally {
      this.importingScript = false
    }
  }

  private async importUserApiFromUrl(): Promise<void> {
    if (this.importingScript) {
      return
    }
    if (this.userApiUrl.trim().length == 0) {
      promptAction.showToast({ message: '请输入脚本 URL', duration: 2000 })
      return
    }
    this.importingScript = true
    try {
      try {
        const info = await SourceEngine.getInstance().importFromUrl(this.userApiUrl)
        await SourceEngine.getInstance().loadSource(info.id)
        this.refreshUserApiState()
        promptAction.showToast({ message: `「${info.name}」已导入并加载`, duration: 2500 })
      } catch (e) {
        this.refreshUserApiState()
        promptAction.showToast({ message: `导入失败：${(e as BusinessError).message ?? '网络错误'}`, duration: 3000 })
      }
    } finally {
      this.importingScript = false
    }
  }

  private async loadUserApi(id: string): Promise<void> {
    if (id == this.userApiState.loadedId) {
      return
    }
    this.importingScript = true
    try {
      await SourceEngine.getInstance().loadSource(id)
      this.refreshUserApiState()
      const name: string = this.userApiState.meta != undefined ? this.userApiState.meta.name : '音源'
      promptAction.showToast({ message: `「${name}」已激活`, duration: 2000 })
    } catch (e) {
      this.refreshUserApiState()
      promptAction.showToast({ message: `激活失败：${(e as BusinessError).message ?? '未知错误'}`, duration: 3000 })
    } finally {
      this.importingScript = false
    }
  }

  private removeUserApiById(id: string, name: string): void {
    promptAction.showDialog({
      title: '移除音源',
      message: `将移除「${name}」，确定继续吗？`,
      buttons: [
        { text: '取消', color: $r('app.color.text_secondary') },
        { text: '移除', color: '#E05454' }
      ]
    }).then(async (result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index == 1) {
        SourceEngine.getInstance().removeSource(id)
        this.refreshUserApiState()
        promptAction.showToast({ message: '音源已移除', duration: 1500 })
      }
    }).catch(() => {
      // 对话框取消
    })
  }

  build() {
    Column({ space: 12 }) {
      SettingSectionTitle('基本')

      Column() {
        SettingRadioRow('主题', this.themeLabel(), () => {
          this.showThemeSheet = true
        })
        SettingDivider()
        SettingSwitchRow('启动后自动播放音乐', '启动时恢复上次播放位置并直接开始播放',
          this.settings.startupAutoPlay, (on: boolean) => {
            this.update(s => {
              s.startupAutoPlay = on
            })
          })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      // 自定义音源
      SettingSectionTitle('自定义音源')

      Column({ space: 8 }) {
        SettingHint('导入第三方音源脚本（.js），用于获取在线歌曲的播放链接与歌词。\n支持导入多个音源，点击「激活」切换当前使用的音源。')

        if (this.userApiState.error.length > 0) {
          Text(this.userApiState.error)
            .fontSize(11)
            .fontColor('#E05454')
            .width('100%')
        }

        ForEach(this.userApiState.allSources, (src: SourceInfo) => {
          Column({ space: 4 }) {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(src.name.length > 0 ? src.name : '未命名脚本')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(src.author.length > 0 ? `作者：${src.author}` : '未署名')
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              if (src.id == this.userApiState.loadedId) {
                Text('已激活')
                  .fontSize(11)
                  .fontColor($r('app.color.theme_primary'))
              } else {
                Text(src.version.length > 0 ? `v${src.version}` : '')
                  .fontSize(11)
                  .fontColor($r('app.color.text_secondary'))
              }
            }
            .width('100%')

            Row({ space: 10 }) {
              if (src.id != this.userApiState.loadedId) {
                Button('激活')
                  .layoutWeight(1)
                  .height(34)
                  .fontSize(13)
                  .type(ButtonType.Capsule)
                  .backgroundColor($r('app.color.theme_primary'))
                  .fontColor(Color.White)
                  .enabled(!this.importingScript)
                  .onClick(() => {
                    void this.loadUserApi(src.id)
                  })
              }
              Button('移除')
                .layoutWeight(1)
                .height(34)
                .fontSize(13)
                .type(ButtonType.Capsule)
                .backgroundColor($r('app.color.bg_page'))
                .fontColor('#E05454')
                .onClick(() => {
                  this.removeUserApiById(src.id, src.name.length > 0 ? src.name : '未命名脚本')
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .border({
            width: { top: 1 },
            color: { top: $r('app.color.divider') }
          })
        }, (src: SourceInfo) => src.id)

        Divider().color($r('app.color.divider')).height(1)

        Button(this.importingScript ? '导入中…' : '从文件导入脚本')
          .width('100%')
          .height(38)
          .fontSize(13)
          .type(ButtonType.Capsule)
          .backgroundColor($r('app.color.theme_primary'))
          .fontColor(Color.White)
          .enabled(!this.importingScript)
          .onClick(() => {
            void this.importUserApi()
          })

        Column({ space: 4 }) {
          Text('从 URL 导入')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          TextInput({ text: this.userApiUrl, placeholder: 'https://example.com/api.js' })
            .fontSize(13)
            .height(38)
            .width('100%')
            .onChange((value: string) => {
              this.userApiUrl = value
            })
          Button(this.importingScript ? '导入中…' : '下载导入')
            .width('100%')
            .height(36)
            .fontSize(13)
            .type(ButtonType.Capsule)
            .backgroundColor($r('app.color.bg_page'))
            .fontColor($r('app.color.text_primary'))
            .enabled(!this.importingScript)
            .onClick(() => {
              void this.importUserApiFromUrl()
            })
        }
        .width('100%')
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

    }
    .width('100%')
    .bindSheet($$this.showThemeSheet, this.ThemeSheetBuilder(), {
      height: 280,
      dragBar: true,
      backgroundColor: $r('app.color.bg_card'),
      onDisappear: () => {
        this.showThemeSheet = false
      }
    })
  }

  @Builder
  ThemeSheetBuilder() {
    SettingOptionSheet({
      title: '主题',
      options: this.themeOptions,
      selectedIndex: this.settings.themeMode == 'auto' ? 0 : (this.settings.themeMode == 'light' ? 1 : 2),
      onSelect: (index: number) => {
        const mode: ThemeMode = index == 0 ? 'auto' : (index == 1 ? 'light' : 'dark')
        this.update(s => {
          s.themeMode = mode
        })
      },
      onClose: () => {
        this.showThemeSheet = false
      }
    })
  }
}
