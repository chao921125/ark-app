# JS 启动模态配置<a name="ZH-CN_TOPIC_0000001080439964"></a>

### 简介

本示例主要演示 JS UI 框架提供半模态和弹窗模态的启动方式。

使用半模态 FA 或者弹窗模态 FA 时，对应的 ability 在 config.json 中配置相关透明主题并通过设置相应的 window\_modal 参数来使能相应的启动模态。

window\_modal 参数可以通过调用在 startAbility 时在 intent 对象中进行设置，也可以在应用本身的 ability 类的 onStart 方法中进行设置。

### 使用说明

通过点击不同的按钮，来弹出各个不同的弹窗，以此比较进而展示效果。

### 约束与限制

1.本示例支持在大型系统上运行。

2.验证本示例的系统版本号：2.0.0.202110110309(DEVC00E1R53dexlog) GPU Turbo。

3.验证本示例的HarmonyOS版本：2.0.0 Devloper Beta3。

4.本示例需要使用 DevEco Studio 3.0 Beta3 (Build Version:3.0.0.533,built on September 26,2021) 才可编译。
