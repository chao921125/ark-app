/**
 * 关于分区 — 对齐上游 `Setting/settings/About`
 */
import { promptAction } from '@kit.ArkUI'
import { SettingSectionTitle, SettingActionRow, SettingDivider, SettingHint } from '../../components/setting/SettingWidgets'

@Component
export struct AboutSection {
  build() {
    Column({ space: 12 }) {
      SettingSectionTitle('关于')

      Column() {
        SettingActionRow('应用名称', 'CCN 音乐', '', () => {
          // 纯展示项
        })
        SettingDivider()
        SettingActionRow('版本号', '', '1.0.0', () => {
          // 纯展示项
        })
        SettingDivider()
        SettingActionRow('开源协议', '基于 Apache License 2.0 移植并改造', '查看', () => {
          promptAction.showDialog({
            title: '开源协议',
            message: '本应用基于开源项目 lyswhut/lx-music-mobile v1.8.4（Apache License 2.0）' +
              '进行 HarmonyOS 平台移植与改造，遵循原协议。',
            buttons: [
              { text: '知道了', color: $r('app.color.theme_primary') }
            ]
          }).catch(() => {
            // 对话框取消
          })
        })
        SettingDivider()
        SettingActionRow('上游项目', 'github.com/lyswhut/lx-music-mobile', '', () => {
          promptAction.showDialog({
            title: '上游项目',
            message: '本应用移植自 github.com/lyswhut/lx-music-mobile。\n\n' +
              '感谢原作者与社区贡献者。',
            buttons: [
              { text: '知道了', color: $r('app.color.theme_primary') }
            ]
          }).catch(() => {
            // 对话框取消
          })
        })
      }
      .padding(14)
      .borderRadius(12)
      .backgroundColor($r('app.color.bg_card'))

      SettingHint('上游的「软件更新」分区依赖其更新服务，本项目暂未内置更新检查，故不提供。')
    }
    .width('100%')
  }
}
