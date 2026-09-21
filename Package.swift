// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TODOFirstCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "TODOFirstCore", targets: ["TODOFirstCore"])],
    targets: [
        .target(name: "TODOFirstCore", path: "Shared/Tasks"),
        .testTarget(name: "TODOFirstCoreTests", dependencies: ["TODOFirstCore"], path: "Tests/TODOFirstCoreTests")
    ]
)
