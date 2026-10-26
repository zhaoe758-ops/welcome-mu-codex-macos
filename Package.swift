// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WelcomeMU",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "WelcomeMU", targets: ["WelcomeMU"])
    ],
    targets: [
        .executableTarget(
            name: "WelcomeMU",
            path: "Sources/WelcomeMU",
            resources: [.process("Resources")]
        )
    ]
)
