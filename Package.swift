// swift-tools-version:6.0
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
        .binaryTarget(
            name: "ChaportSDK",
            path: "Frameworks/ChaportSDK.xcframework"
        )
    ]
)
