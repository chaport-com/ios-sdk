// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Chaport",
    platforms: [.iOS(.v15)],
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
