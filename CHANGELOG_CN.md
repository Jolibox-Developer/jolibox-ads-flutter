# 更新日志

> English documentation: [CHANGELOG.md](CHANGELOG.md)

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
