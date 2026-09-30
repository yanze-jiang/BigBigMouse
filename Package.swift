// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BigBigMouse",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "BigBigMouse", targets: ["BigBigMouse"])],
    targets: [
        .target(name: "ScrollCore"),
        .executableTarget(name: "BigBigMouse", dependencies: ["ScrollCore"]),
        .executableTarget(name: "ScrollCoreChecks", dependencies: ["ScrollCore"], path: "Tests/ScrollCoreTests")
    ]
)
