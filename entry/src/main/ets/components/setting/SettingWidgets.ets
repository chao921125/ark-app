/**
 * 设置页通用行控件
 *
 * 用**全局 @Builder 函数**（不在 struct 内）而非组件，原因是各分区文件可直接在自己的
 * build 里组合这些行，无需层层包一层组件，也避开了 @BuilderParam 跨文件传参的约束。
 *
 * 视觉规范沿用本项目既有设置页：标题 15px、说明 11px、主题色强调、卡片 bg_card + 12px 圆角。
 * 分组标题的「左侧主题色竖条」对齐上游 lx-music-mobile 的 Section 组件。
 */

/** 分组标题：左侧 4px 主题色竖条 + 16px 标题 */
@Builder
export function SettingSectionTitle(title: string) {
  Row() {
    Row()
      .width(4)
      .height(16)
      .backgroundColor($r('app.color.theme_primary'))
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_primary'))
      .margin({ left: 12 })
  }
  .width('100%')
  .alignItems(VerticalAlign.Center)
  .margin({ bottom: 10 })
}

/** 卡片内分隔线 */
@Builder
export function SettingDivider() {
  Divider()
    .color($r('app.color.divider'))
    .height(1)
}

/** 开关行：标题 + 副说明 + 右侧开关 */
@Builder
export function SettingSwitchRow(title: string, desc: string, isOn: boolean, onChange: (value: boolean) => void) {
  Row() {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
      if (desc.length > 0) {
        Text(desc)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    Blank()
    Toggle({ type: ToggleType.Switch, isOn: isOn })
      .selectedColor($r('app.color.theme_primary'))
      .onChange((value: boolean) => {
        onChange(value)
      })
  }
  .width('100%')
  .padding({ top: 10, bottom: 10 })
}

/** 单选行：标题 + 右侧当前值 + 箭头（点击后由上层弹选择层） */
@Builder
export function SettingRadioRow(title: string, value: string, onClick: () => void) {
  Row() {
    Text(title)
      .fontSize(15)
      .fontColor($r('app.color.text_primary'))
      .layoutWeight(1)
    Text(value)
      .fontSize(13)
      .fontColor($r('app.color.text_secondary'))
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    Text('›')
      .fontSize(16)
      .fontColor($r('app.color.text_secondary'))
      .margin({ left: 6 })
  }
  .width('100%')
  .padding({ top: 12, bottom: 12 })
  .onClick(() => {
    onClick()
  })
}

/** 滑块行：标题 + 右侧当前值 + 滑块 */
@Builder
export function SettingSliderRow(title: string, value: number, min: number, max: number, step: number,
  onChange: (value: number) => void) {
  Column({ space: 4 }) {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(`${value}`)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    Slider({ value: value, min: min, max: max, step: step, style: SliderStyle.OutSet })
      .selectedColor($r('app.color.theme_primary'))
      .width('100%')
      .onChange((v: number, mode: SliderChangeMode) => {
        if (mode == SliderChangeMode.End || mode == SliderChangeMode.Click) {
          onChange(v)
        }
      })
  }
  .width('100%')
  .padding({ top: 10, bottom: 8 })
}

/** 输入行：标签 + 输入框 */
@Builder
export function SettingInputRow(label: string, text: string, placeholder: string, onChange: (value: string) => void) {
  Column({ space: 4 }) {
    Text(label)
      .fontSize(14)
      .fontColor($r('app.color.text_primary'))
    TextInput({ text: text, placeholder: placeholder })
      .fontSize(13)
      .height(38)
      .width('100%')
      .onChange((value: string) => {
        onChange(value)
      })
  }
  .width('100%')
  .padding({ top: 8, bottom: 8 })
}

/** 操作行：标题 + 副说明 + 右侧动作文字（整行可点） */
@Builder
export function SettingActionRow(title: string, desc: string, actionText: string, onClick: () => void) {
  Row() {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
      if (desc.length > 0) {
        Text(desc)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    if (actionText.length > 0) {
      Text(actionText)
        .fontSize(13)
        .fontColor($r('app.color.theme_primary'))
        .margin({ left: 10 })
    }
  }
  .width('100%')
  .padding({ top: 11, bottom: 11 })
  .onClick(() => {
    onClick()
  })
}

/** 说明文字（分区内的提示） */
@Builder
export function SettingHint(text: string) {
  Text(text)
    .fontSize(11)
    .fontColor($r('app.color.text_secondary'))
    .width('100%')
}
