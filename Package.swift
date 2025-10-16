// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DropletRippleShader",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RippleField", targets: ["RippleField"]),
    ],
    targets: [
        .target(
            name: "RippleField",
            path: "Sources/RippleField",
            sources: [
                "Core",
                "Modifiers",
                "View",
                "Support"
            ],
            resources: [
                .process("Shaders")
            ]
        )
        // Examples are not an SPM target; they’re for local running only.
    ]
)
