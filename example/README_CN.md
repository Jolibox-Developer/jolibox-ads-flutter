# Jolibox Ads Flutter 示例

此示例是 Flutter 桥接层的本地验收应用，覆盖 Banner、插屏和激励视频广告；其中不包含
`joliSource` 或已配置的场景值。

## 运行方式

1. 先按上级[接入文档](../README_CN.md)完成 Android 或 iOS 原生配置。
2. 将 `qa.local.json.example` 复制为 `qa.local.json`，填写 Staging 环境提供的参数。该本地
   文件已被 Git 忽略。
3. 使用本地配置运行：

   ```bash
   flutter run --dart-define-from-file=qa.local.json
   ```

只有宿主明确将首次原生 SDK 初始化委托给 Flutter 时，才点击 **Initialize**。对于已经在
原生层完成初始化的混编宿主，不要点击该按钮；原生初始化成功后再使用广告控件。

初始化成功后，Banner Widget 会自动请求广告。插屏和激励视频使用独立的 Load、Show 控件，
用于验证对象式生命周期。生产接入方式和回调语义请参考上级文档。

For English, see [README.md](README.md).
