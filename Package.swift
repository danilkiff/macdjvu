// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacDjVu",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "MacDjVuCore"
        ),
        .executableTarget(
            name: "MacDjVu",
            dependencies: ["MacDjVuCore"]
        ),
        .testTarget(
            name: "MacDjVuCoreTests",
            dependencies: ["MacDjVuCore"]
        ),
    ]
)
