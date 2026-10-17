// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LidDuck",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LidDuck", targets: ["LidDuck"])
    ],
    targets: [
        .executableTarget(
            name: "LidDuck",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreAudio")
            ]
        ),
        .testTarget(name: "LidDuckTests", dependencies: ["LidDuck"])
    ]
)
