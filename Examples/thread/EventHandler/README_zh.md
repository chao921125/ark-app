# 线程间通信<a name="ZH-CN_TOPIC_0000001127136651"></a>

### 简介

EventHandler 的主要功能是将 InnerEvent 事件或者 Runnable 任务投递到其他的线程进行处理;

EventRunner 的工作模式可以分为托管模式和手动模式。两种模式是在调用 EventRunner 的 create\(\) 方法时，通过选择不同的参数来实现的。

### 使用说明

1.点击“Send InnerEvent”，发送 InnerEvent事件

2.点击“Post Runnable Task”，发送Runnable 任务

3.点击“Send Event To OriginalThread”，发送事件到线程中

### 约束与限制

1.本示例仅支持在大型系统上运行。

2.验证本示例的系统版本号：2.0.0.202110110309(DEVC00E1R53dexlog) GPU Turbo。

3.验证本示例的HarmonyOS版本：2.0.0 Devloper Beta3。

4.本示例需要使用 DevEco Studio 3.0 Beta3 (Build Version:3.0.0.533,built on September 26,2021) 才可编译。
