// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Feature flag: the Mac App Store shell is developed dual-track but not
// released. Default builds produce only the Developer ID app; set KONA_MAS=1
// to also build the KonaAppStore product (e.g. `KONA_MAS=1 swift build`).
let includeMASShell = ProcessInfo.processInfo.environment["KONA_MAS"] == "1"

var products: [Product] = [
    .executable(name: "Kona", targets: ["Kona"])
]

var targets: [Target] = [
    // Everything both distribution shells share: models, managers, views,
    // and the base app delegate. Must stay free of Sparkle.
    .target(
        name: "KonaCore"
    ),
    // Developer ID build: Sparkle auto-updates, distributed via GitHub Releases.
    .executableTarget(
        name: "Kona",
        dependencies: [
            "KonaCore",
            .product(name: "Sparkle", package: "Sparkle")
        ],
        linkerSettings: [
            // Sparkle.framework is embedded in Contents/Frameworks by Scripts/bundle.sh
            .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
        ]
    ),
    .testTarget(
        name: "KonaTests",
        dependencies: ["KonaCore"]
    )
]

if includeMASShell {
    // Mac App Store build: sandboxed, no Sparkle (the App Store handles updates).
    products.append(.executable(name: "KonaAppStore", targets: ["KonaAppStore"]))
    targets.append(
        .executableTarget(
            name: "KonaAppStore",
            dependencies: ["KonaCore"]
        )
    )
}

let package = Package(
    name: "Kona",
    platforms: [
        .macOS(.v14)
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: targets
)
