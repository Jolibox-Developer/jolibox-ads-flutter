// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "jolibox_ads_flutter",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "jolibox-ads-flutter", targets: ["jolibox_ads_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/Jolibox-Developer/jolibox-ios-sdk.git", exact: "0.3.0")
    ],
    targets: [
        .target(
            name: "jolibox_ads_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "JoliboxSDKAll", package: "jolibox-ios-sdk")
            ]
        )
    ]
)
