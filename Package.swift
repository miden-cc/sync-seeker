// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SyncSeeker",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "SyncSeeker", targets: ["SyncSeeker"]),
        .executable(name: "SyncSeekerApp", targets: ["SyncSeekerApp"])
    ],
    targets: [
        .target(
            name: "SyncSeeker",
            path: "Sources/SyncSeeker"
        ),
        .executableTarget(
            name: "SyncSeekerApp",
            dependencies: ["SyncSeeker"],
            path: "Sources/SyncSeekerApp"
        ),
        .testTarget(
            name: "SyncSeekerTests",
            dependencies: ["SyncSeeker"],
            path: "Tests/SyncSeekerTests"
        )
    ]
)
