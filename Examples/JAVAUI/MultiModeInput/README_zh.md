# 多模输入<a name="ZH-CN_TOPIC_0000001126596074"></a>

### 简介<a name="section104mcpsimp"></a>

本示例通过实现相关接口KeyEventListener、TouchEventListener、SpeechEventListener等，对相应的事件进行处理，例如按键事件、触摸事件、语音事件等。

### 使用说明<a name="section107mcpsimp"></a>

本事例主页面包含触摸事件按钮、按键事件按钮、鼠标事件按钮、语音事件按钮；

1.  当点击触摸事件按钮时，跳转到另一个页面，用手指触摸当前页面上的按钮，页面上会弹出提示框显示触摸事件；
2.  当点击按键事件按钮时，跳转到另一个页面，按手机的音量键，页面上会弹出提示框显示按键事件；
3.  当点击鼠标事件按钮时，跳转到另一个页面，用鼠标左键点击当前页面上的按钮，页面上会弹出提示框显示鼠标事件；
4.  当点击语音事件按钮时，跳转到另一个页面，按智慧屏遥控器上的语音按钮，页面上会弹出提示框显示语音事件。

### 约束与限制<a name="section115mcpsimp"></a>

1.本示例仅支持在标准系统上运行；

2.多模输入事件在不同形态产品支持的情况请[点击链接](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/ui-multimodal-overview-0000000000031876)查看。

3.验证本示例的系统版本号：2.0.0.202110110309(DEVC00E1R53dexlog) GPU Turbo。

4.验证本示例的HarmonyOS版本：2.0.0 Devloper Beta3。

5.本示例需要使用 DevEco Studio 3.0 Beta3 (Build Version:3.0.0.533,built on September 26,2021) 才可编译。
