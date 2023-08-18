# Native_image



### 简介

Native_image提供对像素数据和像素图信息的访问，本示例展示了如何声明JNI接口并通过JNI接口锁定和访问或解锁像素数据的函数。

### 使用说明

1.点击**获取Pixels**，获取给定**PixelMap**对象的内存地址并锁定内存，显示返回的调用结果。

2.点击**获取PixelMap信息**，返回PixelMap对象信息并显示。

3.点击**解锁Pixels**，显示返回的调用结果。

### 约束与限制

1.本示例仅支持在大型系统上运行。

2.验证本示例的系统版本号：2.0.0.202110110309(DEVC00E1R53dexlog) GPU Turbo。

3.验证本示例的HarmonyOS版本：2.0.0 Devloper Beta3。

4.本示例需要使用 DevEco Studio 3.0 Beta3 (Build Version:3.0.0.533,built on September 26,2021) 才可编译。
