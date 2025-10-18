// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DropletRippleShader",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RippleField", targets: ["RippleField"]),
    ],
    targets: [
        .target(
            name: "RippleField",
            // Point at the folder that contains Core/, Modifiers/, View/, Shaders/, etc.
            path: "Sources/RippleField",
            resources: [
                // Keep this bundle so Bundle.module resolves even when CI strips SwiftUI assets.
                .process("Resources")
            ]
            // ⛔️ Do NOT specify `sources:` subfolders; let SwiftPM discover all Swift/.metal files inside.
            // ⛔️ Do NOT put .metal in `resources:` for SwiftUI stitchable shaders.
        ),
        .testTarget(
            name: "RippleFieldTests",
            dependencies: ["RippleField"],
            path: "Tests/RippleFieldTests"
        ),
    ]
)
