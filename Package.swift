// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Kona",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Kona", targets: ["Kona"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Kona",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                // Sparkle.framework is embedded in Contents/Frameworks by Scripts/bundle.sh
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "KonaTests",
            dependencies: ["Kona"]
        )
    ]
)
