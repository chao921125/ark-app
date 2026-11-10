/**
 * 设置页通用选项弹层 — 从若干选项中单选
 * 用于播放模式、音质、主题、添加位置等「右侧显示当前值 + 点击切换」的项。
 */
@Component
export struct SettingOptionSheet {
  title: string = ''
  options: string[] = []
  selectedIndex: number = -1
  onSelect: (index: number) => void = () => {}
  onClose: () => void = () => {}

  build() {
    Column() {
      Text(this.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 8 })

      ForEach(this.options, (opt: string, index: number) => {
        Row() {
          Text(opt)
            .fontSize(15)
            .fontColor(index == this.selectedIndex ? $r('app.color.theme_primary') : $r('app.color.text_primary'))
            .layoutWeight(1)
          if (index == this.selectedIndex) {
            Text('✓')
              .fontSize(15)
              .fontColor($r('app.color.theme_primary'))
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .onClick(() => {
          this.onSelect(index)
          this.onClose()
        })
      }, (opt: string, index: number) => `${opt}_${index}`)

      Button('取消')
        .width('100%')
        .height(40)
        .fontSize(14)
        .type(ButtonType.Capsule)
        .backgroundColor($r('app.color.bg_page'))
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 10, bottom: 12 })
        .onClick(() => {
          this.onClose()
        })
    }
    .width('100%')
    .backgroundColor($r('app.color.bg_card'))
  }
}
