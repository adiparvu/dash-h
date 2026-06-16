// swift-tools-version: 6.0
import PackageDescription

// PRVIO EARTH — Swift Package
//
// Packages the reusable core (DesignSystem, Models, Engine, Features) so it
// can be shared by the iOS app, the visionOS app, the Widget Extension and
// the test suite. The @main app, Widget Extension and Live Activity are wired
// up as Xcode application/extension targets that depend on `PrvioEarthCore`
// (see docs/ARCHITECTURE.md → "Targets & Project Layout").

let package = Package(
    name: "PrvioEarth",
    platforms: [
        .iOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(name: "PrvioEarthCore", targets: ["PrvioEarthCore"])
    ],
    targets: [
        .target(
            name: "PrvioEarthCore",
            path: "Sources",
            exclude: [
                "App/PrvioEarthApp.swift",   // @main lives in the app target
                "Widgets",                    // Widget Extension target
                "Spatial"                     // visionOS app target
            ]
        ),
        .testTarget(
            name: "PrvioEarthTests",
            dependencies: ["PrvioEarthCore"],
            path: "Tests"
        )
    ]
)
