# 资源文件

### 简介

应用的资源文件（字符串、图片、音频等）统一存放于 resources 目录下，便于开发者使用和维护。resources 目录包括两大类，一类为 base 目录与限定词目录，用于存放特定类型的资源文件，另一类为 rawfile 目录，支持创建多层子目录，目录名称可以自定义，文件夹内可以自由放置各类资源文件。本示例通过读取 Resources 目录下的不同系统资源文件案例，来演示资源文件的使用。

### 使用说明

打开应用，界面中为用户展示了从resources 下读取到的各类资源文件内容，包括base下boolean,color,floats,intArray,integer,plural,strarray等特定资源文件中的内容和 rawfile中文件中的内容。

### 约束与限制

1.本示例仅支持在大型系统上运行。

2.验证本示例的系统版本号：2.0.0.202110110309(DEVC00E1R53dexlog) GPU Turbo。

3.验证本示例的HarmonyOS版本：2.0.0 Devloper Beta3。

4.本示例需要使用 DevEco Studio 3.0 Beta3 (Build Version:3.0.0.533,built on September 26,2021) 才可编译。
