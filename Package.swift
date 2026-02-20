// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CalBuddy",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0")
    ],
    targets: [
        .executableTarget(
            name: "CalBuddy",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/CalBuddy",
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        ),
        .testTarget(
            name: "CalBuddyTests",
            dependencies: ["CalBuddy"],
            path: "Tests/CalBuddyTests"
        )
    ]
)
