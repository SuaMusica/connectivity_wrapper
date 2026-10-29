// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "connectivity_wrapper",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "connectivity-wrapper", targets: ["connectivity_wrapper"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "connectivity_wrapper",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                // .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
