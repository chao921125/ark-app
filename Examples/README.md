# 应用示例

-   [概要简介](#section1470103520301)
-   [目录](#sectionMenu)
-   [使用说明](#section17988202503116)
-   [约束与限制](#section18841871178)
-   [相关仓](#section741114082513)

## 概要简介

为帮助开发者快速熟悉HarmonyOS SDK所提供的API和应用开发流程，我们提供了一系列的应用示例，即Sample。每一个应用示例都是一个独立的DevEco Studio工程项目，开发者可以将工程导入到DevEco Studio开发工具，通过浏览代码、编译工程、安装和运行应用示例来了解应用示例中涉及API的使用方法。

## 目录<a name="sectionMenu"></a>
- AI
  - [`AIFunctionSet:` AI能力（Java）（API5）](AI/AIFunctionSet)
- AccessibilityService 
  - [`AccessibilityService:`无障碍服务（Java）（API6）](AccessibilityService/AccessibilityService)
- CompleteApps
  - [`DistributedSearch:`分布式搜索（Java）（API5）](CompleteApps/DistributedSearch) 
  - [`DistributedShoppingCart:`分布式购物车（Java）（API5）](CompleteApps/DistributedShoppingCart) 
  - [`TicTacToeGame:`井字过三关（Java）（API5）](CompleteApps/TicTacToeGame) 
- ETSUI
  - [`eTSBuildCommonView:`创建简单视图（ArkTS）（API7）](ETSUI/eTSBuildCommonView) 
  - [`eTSDefiningPageLayoutAndConnection:`页面布局和连接（ArkTS）（API7）](ETSUI/eTSDefiningPageLayoutAndConnection)
  - [`eTSDrawingAndAnimation:`绘图和动画（ArkTS）（API7）](ETSUI/eTSDrawingAndAnimation)
  - [`BorderImageSample:`组件图片动态边框 （ArkTS）（API9）](ETSUI/BorderImageSample)
  - [`ColorFilterSample:`设置图片颜色（ArkTS）（API9）](ETSUI/ColorFilterSample)
  - [`AboutSample:`应用关于页面（ArkTS）（API9）](ETSUI/AboutSample)
  - [`BusinessSample:`个人信息页面（ArkTS）（API9）](ETSUI/BusinessSample)
  - [`CategoryListSample:`分类列表页面（ArkTS）（API9）](ETSUI/CategoryListSample)
  - [`CategorySample:`分页布局（ArkTS）（API9）](ETSUI/CategorySample)
  - [`GridSample:`宫格布局（ArkTS）（API9）](ETSUI/GridSample)
  - [`ListSample:`列表内容页面（ArkTS）（API9）](ETSUI/ListSample)
  - [`LoginSample:`应用登录页面（ArkTS）（API9）](ETSUI/LoginSample)
  - [`SplashScreenSample:`应用启动过渡页面（ArkTS）（API9）](ETSUI/SplashScreenSample)
  - [`HealthyDiet:`健康饮食（ArkTS）（API9）](ETSUI/HealthyDiet)
  - [`TransitionAnimation:`转场动画（ArkTS）（API9）](ETSUI/TransitionAnimation)
  - [`Search:`融合搜索（ArkTS）（API9）](ETSUI/Search)
- JAVAUI
  - [`Animation:`动画（Java）（API）（API5）](JAVAUI/Animation) 
  - [`CommonLayout:`常用布局（Java）（API5）](JAVAUI/CommonLayout)   
  - [`Components:`组件（Java）（API5）（API5）](JAVAUI/Components) 
  - [`CustomComponent:`自定义组件（Java）（API5）](JAVAUI/CustomComponent)   
  - [`CustomLayout:`自定义布局（Java）（API5）](JAVAUI/CustomLayout) 
  - [`Dialog:`对话框（Java）（API5）](JAVAUI/Dialog) 
  - [`List:`列表容器（Java）（API5）](JAVAUI/List) 
  - [`Localization:`时区与语言（Java）（API5）](JAVAUI/Localization) 
  - [`MultiModeInput:`多模输入（Java）（API5）](JAVAUI/MultiModeInput) 
  - [`MultimodalEvent:`多模输入事件标准化（Java）（API5）](JAVAUI/MultimodalEvent) 
  - [`PositionLayout:`位置布局（Java）（API5）](JAVAUI/PositionLayout) 
  - [`ProgressBar:`进度条（Java）（API5）](JAVAUI/ProgressBar) 
  - [`TriangleJava:`OpenGL绘制三角形（Java）（API6）](JAVAUI/TriangleJava)   
- JSUI
  - [`Image:`基本动画（JS,Java）（API5）](JSUI/Image) 
  - [`JsAdaptivePortalList:`多设备自适应的效率型首页（JS,Java）（API6）](JSUI/JsAdaptivePortalList) 
  - [`JsAdaptivePortalPage:`多设备自适应的FA页面（JS,Java）（API6）](JSUI/JsAdaptivePortalPage) 
  - [`JsAdaptiveServiceWidget:`多设备自适应服务卡片（JS,Java）（API5）](JSUI/JsAdaptiveServiceWidget) 
  - [`JsAnimation:`动效示例应用（JS,Java）（API5）](JSUI/JsAnimation) 
  - [`JsApp:`JsApp（JS,Java）（API5）](JSUI/JsApp) 
  - [`JsCallJava:`JsCallJava（JS,Java）（API5）](JSUI/JsCallJava) 
  - [`JsComponents:`JS组件（JS,Java）（API5）](JSUI/JsComponents) 
  - [`JsDemo:`JS演示（JS,Java）（API5）](JSUI/JsDemo) 
  - [`JsFACard:`JS卡片（JS,Java）（API5）](JSUI/JsFACard) 
  - [`JsGallery:`图库示例应用（JS,Java）（API5）](JSUI/JsGallery) 
  - [`JsShopping:`购物示例应用（JS,Java）（API5）](JSUI/JsShopping) 
  - [`JsStartMode:`JS 启动模态配置（JS,Java）（API5）](JSUI/JsStartMode) 
  - [`UiComponents:`UiComponents（JS,Java）（API5）](JSUI/UiComponents) 
  - [`UserRegistration:`用户注册（JS,Java）（API5）](JSUI/UserRegistration)   
- ability
  - [`AbilityConnection:`Ability连接（Java）（API5）](ability/AbilityConnection)   
  - [`AbilityForm:`AbilityForm（Java）（API6）](ability/AbilityForm)   
  - [`AbilityIntent:`Intent启动Ability（Java）（API5）](ability/AbilityIntent)   
  - [`AbilityInteraction:`Ability交互和迁移（Java）（API5）](ability/AbilityInteraction) 
  - [`CommonEvent:`公共事件（Java）（API5）（API5）](ability/CommonEvent)   
  - [`CustomNotification:`自定义通知（JS）（API5）](ability/CustomNotification)   
  - [`DataAbility:`DataAbility（Java）（API5）](ability/DataAbility)   
  - [`Delegator:`Ability测试（Java）（API5）](ability/Delegator)   
  - [`DistributedMusicPlayer:`分布式音乐播放（Java）（API6）](ability/DistributedMusicPlayer) 
  - [`DistributedScheduler:`分布式任务调度（Java）（API6）](ability/DistributedScheduler)   
  - [`ForegroundService:`前台服务（Java）（API5）](ability/ForegroundService)   
  - [`Fraction:`Fraction（Java）（API5）](ability/Fraction)   
  - [`Idl:`IDL（Java）（API6）](ability/Idl)   
  - [`Intent:`Intent（Java）（API6）](ability/Intent) 
  - [`IntentAgent:`IntentAgent（Java）（API5）](ability/IntentAgent) 
  - [`Notification:`通知（Java）（API5）](ability/Notification) 
  - [`PageAbility:`PageAbility（Java）（API5）](ability/PageAbility) 
  - [`Pasteboard:`剪切板（Java）（API5）](ability/Pasteboard) 
  - [`ServiceAbility:`ServiceAbility（Java）（API5）](ability/ServiceAbility) 
- common
  - [`Download:`下载服务（Java）（API5）](common/Download)
  - [`HelloWorld:`HelloWorld（Java）（API5）](common/HelloWorld)
  - [`Resources:`资源文件（Java）（API5）](common/Resources)
  - [`Timer:`简单计时器（Java）（API5）](common/Timer)
- data
  - [`DistributedPictures:`分布式文件共享（Java）（API5）](data/DistributedPictures)
  - [`ORM:`对象关系映射数据库（Java）（API5）](data/ORM)
  - [`Preferences:`轻量级偏好数据库（ArkTS）（API9）](data/Preferences)
- device
  - [`BatteryInfo:`电池信息（Java）（API5）](device/BatteryInfo)	
  - [`Compass:`指南针（Java）（API5）](device/Compass)	
  - [`Location:`位置（Java）（API5）](device/Location)	
  - [`Setting:`设置（Java）（API5）](device/Setting)	  
- media
  - [`Audio:`音频（Java）（API5）](media/Audio)
  - [`AudioPlayer:`媒体会话（Java）（API5）](media/AudioPlayer)
  - [`Camera:`相机（Java）（API5）](media/Camera)
  - [`PixelMap:`图像（Java）（API5）](media/PixelMap)
  - [`VideoPlayer:`视频播放（Java）（API5）](media/VideoPlayer)  
- native
  - [`JSNativeDemo:`JSNativeDemo（JS,C++）（API7）](native/JSNativeDemo) 
  - [`NativeImage:`Native_image（Java,C++）（API6）](native/NativeImage) 
  - [`NativeLayer:`Native_layer（Java,C++）（API6）](native/NativeLayer)   
- network
  - [`Bluetooth:`蓝牙（Java）（API5）](network/Bluetooth)
  - [`DistributedAbility:`设备和服务的发现和连接（Java）（API6）](network/DistributedAbility)
  - [`DistributedDevices:`分布式设备（Java）（API5）](network/DistributedDevices)
  - [`NFC:`NFC（Java）（API5）](network/NFC)
  - [`NetworkManagement:`网络管理（Java）（API5）](network/NetworkManagement)
  - [`WLAN:`WLAN（Java）（API5）](network/WLAN)  
- security
  - [`DataSecurity:`数据安全（Java）（API5）](security/DataSecurity)  
  - [`FaceRecognition:`人脸识别（Java）（API5）](security/FaceRecognition)  
  - [`Permission:`应用权限（Java）（API5）](security/Permission)    
- thread
  - [`EventHandler:`线程间通信（Java）（API5）](thread/EventHandler)  
  - [`TaskDispatcher:`线程管理（Java）（API5）](thread/TaskDispatcher)  
- MultiDeviceAppDev
  - [`MusicAlbum:`一多音乐专辑主页（ArkTS）（API9）](MultiDeviceAppDev/MusicAlbum)
  
## 使用说明

1.  将独立的应用示例工程导入DevEco Studio进行编译构建及运行调试。
2.  部分应用示例中含有多个模块，开发者可以选择对单个模块进行编译构建，生成一个HAP应用安装包，也可以对整个工程进行编译构建，生成多个HAP应用安装包。
3.  安装运行后，即可在设备上查看应用示例运行效果，以及进行相关调试。

## 约束与限制

1.  安装运行应用示例之前，请先通过config.json文件中的"deviceType"字段来确认该应用示例支持的设备类型，可尝试通过修改该字段使其可以在相应类型的设备上运行（config.json文件一般在代码的entry/src/main路径下，不同的Sample可能会有不同）。
2.  配置开发环境时，如果您想让应用示例运行到HarmonyOS上，请参考[DevEco Studio使用说明](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/tools_overview-0000001053582387)。
3.  Readme中标注为“支持标准系统”或“支持小型系统”的应用示例支持在OpenHarmony上运行，标注为“支持大型系统”的应用示例仅支持在HarmonyOS上运行。
4.  所有OpenHarmony相关示例请参考OpenHarmony组织下的[app_samples仓](https://gitee.com/openharmony/app_samples)。

## 相关仓

1.  HarmonyOS场景化复杂应用示例：[HarmonyOS codelabs](https://gitee.com/harmonyos/harmonyos_codelabs)
2.  OpenHarmony基础应用示例：[OpenHarmony app_samples](https://gitee.com/openharmony/app_samples)
3.  OpenHarmony场景化复杂应用示例：[OpenHarmony codelabs](https://gitee.com/openharmony/codelabs)



