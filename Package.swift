// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription
let package = Package(
    name: "XcodeGroupSync",
    platforms: [
            .macOS(.v13)
        ],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .executableTarget(
            name: "XcodeGroupSync",
            dependencies: ["XcodeProj",
                           .product(name: "ArgumentParser", package: "swift-argument-parser")
                          ],

            swiftSettings: [.define("DEBUG", .when(configuration: .debug))]),
        .testTarget(
            name: "XcodeGroupSyncTests",
            dependencies: ["XcodeGroupSync", "XcodeProj"]),
    ]
)
