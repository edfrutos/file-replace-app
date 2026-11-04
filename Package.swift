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
            dependencies: ["FileReplaceCore"],
            // Lo usa el target de Xcode (App Store); el DMG no lleva sandbox.
            exclude: ["Replacer.entitlements"]
        ),
        .testTarget(
            name: "FileReplaceCoreTests",
            dependencies: ["FileReplaceCore"]
        )
    ]
)
