// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OverflowPeek",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OverflowPeek", targets: ["OverflowPeek"])
    ],
    targets: [
        .executableTarget(
            name: "OverflowPeek",
            path: "Sources/OverflowPeek",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Combine")
            ]
        )
    ]
)
