// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AIUsageMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AIUsageMenuBar", targets: ["AIUsageMenuBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .executableTarget(
            name: "AIUsageMenuBar",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/AIUsageMenuBar",
            resources: [.process("Resources")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "AIUsageMenuBarTests",
            dependencies: ["AIUsageMenuBar"],
            path: "Tests/AIUsageMenuBarTests"
        )
    ]
)
