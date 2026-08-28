// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Replacer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Replacer", targets: ["FileReplaceApp"]),
        .library(name: "FileReplaceCore", targets: ["FileReplaceCore"])
    ],
    targets: [
        .target(name: "FileReplaceCore"),
        .executableTarget(
            name: "FileReplaceApp",
            dependencies: ["FileReplaceCore"]
        ),
        .testTarget(
            name: "FileReplaceCoreTests",
            dependencies: ["FileReplaceCore"]
        )
    ]
)
