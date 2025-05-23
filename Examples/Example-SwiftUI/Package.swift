// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Example-SwiftUI",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .executable(name: "Example-SwiftUI", targets: ["Example-SwiftUI"])
    ],
    dependencies: [
        // Assuming your SDK is hosted in the same repo or elsewhere
        .package(url: "https://github.com/chaport-com/ios-sdk.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Example-SwiftUI",
            dependencies: ["ChaportSDK"],
            path: "Example-SwiftUI",
        )
    ]
)