# 更新日志

> English documentation: [CHANGELOG.md](CHANGELOG.md)

## 0.6.8

- 内置已从远端验证、且不含失效归档期签名的 iOS `0.6.4` XCFramework。
- 扩展公开面检查，拒绝内置构建期代码签名。
- 保持 Flutter `3.22.3`、Kotlin `2.0.21`、Android Native `0.6.2`、Android Google Mobile Ads `24.0.0` 与 iOS Google Mobile Ads `12.1.0`。

## 0.6.7

- 将内置 iOS 原生 framework 替换为不含本机构建路径的 iOS `0.6.3` XCFramework。
- 扩展公开面检查，拒绝本地路径、本地依赖声明、内部地址以及二进制制品中的路径泄露。
- 保持 Flutter `3.22.3`、Kotlin `2.0.21`、Android Native `0.6.2`、Android Google Mobile Ads `24.0.0` 与 iOS Google Mobile Ads `12.1.0`。

## 0.6.6

- 删除接入文档中已过时的迁移说明。

## 0.6.5

- 移除 Jolibox 插件级依赖仓库声明，使宿主可以通过
  `RepositoriesMode.PREFER_SETTINGS` 集中管理仓库。
- 明确 Flutter `3.22.3` 自身不兼容 `RepositoriesMode.FAIL_ON_PROJECT_REPOS`，并在
  settings 级接入示例中补充必需的 Flutter Engine Maven 仓库。
- 区分纯 Flutter 与混编宿主初始化方式，补充已验收工具链基线，并在接入示例中处理可重试的
  全屏展示错误。

## 0.6.4

- Android 调整为 Kotlin `2.0.21`、Android Gradle Plugin `8.6.1`、Gradle `8.7`，保持 `compileSdk 35` 与 Java 17。
- Android 原生聚合依赖升级至兼容 Kotlin `2.0.21` 的 `0.6.2`。
- 补充宿主 Maven 配置位置、必需的 AdMob App ID 与 iOS Google Mobile Ads `12.1.0`。
- 宿主 `onAdLoaded` 自身抛出的异常不再被误报为原生广告加载失败。
- 统一全屏广告终态展示失败处理，并避免 iOS 重新缓存已消费广告。
- 另一个全屏广告正在展示时，当前广告仍保持可重试状态。
- 删除无效的 Android 模板测试，改为真实桥接行为测试，并扩充 Dart 生命周期覆盖。

## 0.6.3

- 将 Flutter 包、Android Gradle 插件和 CocoaPods 元数据统一为 `0.6.3`。
- Android 原生聚合依赖升级至 `0.6.1`。
- 删除会暴露本机构建路径的 Swift ABI 元数据。
- 示例中的非法环境值会明确失败，不再静默回落到 staging。

## 0.6.2

- 将公开 Git 依赖引用统一为 `0.6.2` Flutter bridge 版本。

## 0.6.1

- 新增可运行的 Android/iOS 混编宿主示例和双语接入说明。

## 0.6.0

- 统一 Flutter 对外广告错误码为 `ADS_` 前缀。
- 明确 iOS `0.6.0` 通过 CocoaPods 交付，并固定要求 Flutter `3.22.3`。
- Android Maven 与内置 iOS 原生 SDK 制品统一升级至 `0.6.0`。

## 0.5.0

- Jolibox Ad Mediation Flutter 桥接首个公开版本。
- 支持 Android 与 iOS 的固定尺寸 Banner Widget、插屏和激励视频广告。
- Android 从匹配的公开 GitHub Maven 仓库解析 `jolibox-ad-mediation:0.5.0`。
- iOS 通过 CocoaPods 内置匹配的 `JoliboxAdMediation` XCFramework。
