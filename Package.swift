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
        // Add dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "Kona",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KonaTests",
            dependencies: ["Kona"]
        )
    ]
)