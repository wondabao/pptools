// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PPTTools",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PPTTools", targets: ["PPTTools"])],
    targets: [
        .executableTarget(name: "PPTTools", resources: [.process("Resources")]),
        .testTarget(name: "PPTToolsTests", dependencies: ["PPTTools"])
    ]
)
