# 剪贴板<a name="ZH-CN_TOPIC_0000001127261977"></a>

### 简介

本示例主要展示了应用之间的数据剪贴。同一设备的应用程序A、B之间可以借助系统剪贴板服务完成简单数据的传递，即应用程序A向剪贴板服务写入数据后，应用程序B可以从中读取出数据。

### 使用说明

1.  进入Pasteboard应用，在文本框中输入任意文本内容，点击"Copy Text",复制文本内容到剪切板。
2. 进入paste应用，点击“Paste Text”,将复制的文本内容粘贴到文本框中。
3. 点击“Clear Pasteboard”,清除剪切板上的文本内容。

### 约束与限制

1.本示例仅支持在大型系统上运行。

2.验证本示例的系统版本号：2.0.0.202110110309(DEVC00E1R53dexlog) GPU Turbo。

3.验证本示例的HarmonyOS版本：2.0.0 Devloper Beta3。

4.本示例需要使用 DevEco Studio 3.0 Beta3 (Build Version:3.0.0.533,built on September 26,2021) 才可编译。
