// swift-tools-version:5.9
import PackageDescription

// Local override of the published `maplibre-gl-native-distribution` package,
// vending the same `MapLibre` product from the xcframework that
// bin/build-maplibre-native builds. See DevDependencies/README.md.
//
// The directory name matters: SwiftPM derives package identity from it, and the
// override only applies because that identity matches.
let package = Package(
    name: "MapLibre Native",
    products: [
        .library(name: "MapLibre", targets: ["MapLibre"])
    ],
    targets: [
        .binaryTarget(name: "MapLibre", path: "MapLibre.xcframework")
    ]
)
