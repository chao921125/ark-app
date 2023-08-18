# BusinessSample

### 简介
本示例实现了个人信息页面展示。

### 相关概念
个人信息展示页面主要由三部分组成，最上面是标题，最下面是选项卡，中间是个人信息内容，主要由头像以及列表信息组成。<br>
实现方式：
- 标题：使用Navigation组件实现。
- 个人信息：整体使用Scroll组件实现滑动效果。头像卡片使用Stack堆叠组件实现；列表内容使用List组件实现。
- 选项卡：使用Tabs组件实现。

### 效果预览
![](screenshots/business_gif.gif)

### 使用说明
1. 点击底部四个选项卡可以切换到不同的页面
2. 点击列表内容可以跳转到详细内容页面

### 相关权限
不涉及

### 限制和约束

1.本示例支持API 9及以上的标准系统上运行。

2.本示例支持的SDK版本和DevEco Studio版本：
SDK：3.2.1.4 Canary1及以上。
DevEco Studio版本： DevEco Studio Beta4(Build Version: 3.1.0.100, build on November 3, 2022)及以上。