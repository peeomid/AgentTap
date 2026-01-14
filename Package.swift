// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AgentTap",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "AgentTapCore", targets: ["AgentTapCore"]),
        .executable(name: "AgentTap", targets: ["AgentTap"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AgentTapCore",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "AgentTap",
            dependencies: ["AgentTapCore"],
            path: "Sources/AgentTap",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "AgentTapCoreTests",
            dependencies: ["AgentTapCore"],
            path: "Tests/AgentTapCoreTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ]
)
