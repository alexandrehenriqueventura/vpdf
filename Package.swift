// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "vpdf",
    defaultLocalization: "pt-BR",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "vpdf",
            targets: ["vpdf"]
        )
    ],
    targets: [
        .executableTarget(
            name: "vpdf",
            path: "Sources/vpdf",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "vpdfTests",
            dependencies: ["vpdf"],
            path: "Tests/vpdfTests"
        )
    ]
)
