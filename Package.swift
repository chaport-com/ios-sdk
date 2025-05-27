// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "ChaportSDK",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "ChaportSDK",
            targets: ["ChaportSDK"]
        )
    ],
    targets: [
        .target(
            name: "ChaportSDK",
            path: "Sources"
        )
    ]
)
