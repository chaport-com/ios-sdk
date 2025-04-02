// swift-tools-version:6.1
import PackageDescription

let package = Package(
    name: "ChaportSDK",
    platforms: [.iOS(.v12)],
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
