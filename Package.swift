// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Chaport",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "Chaport",
            targets: ["Chaport"]
        )
    ],
    targets: [
        .target(
            name: "Chaport",
            path: "Sources"
        )
    ]
)
