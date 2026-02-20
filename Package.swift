// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CalBuddy",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "CalBuddy",
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
