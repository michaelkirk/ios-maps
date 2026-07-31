To override a SwiftPM dependency for local editing:

    git submodule add https://github.com/flitsmeister/mapbox-directions-swift DevDependencies/mapbox-directions-swift

Then open DevDependencies in Finder and drag the mapbox-directions-swift directory into Xcode (might as well put it under the DevDependencies group, but I don't think it matters)

Be sure to check "add to target: maps.earth"

You should see your SPM installed dependency disappear.

You can commit these changes while you're working on your branch, but you
probably want to revert them once the changes to your forked dependency
have been upstreamed.

## maplibre-native (built from source)

`maplibre-gl-native-distribution` is a `binaryTarget`, not a source package, so
the submodule trick above doesn't apply.

Build the framework:

    bin/build-maplibre-native

That builds `MapLibre.xcframework` from the `maplibre-native` submodule and
unpacks it into `maplibre-gl-native-distribution/`, a local Swift package
vending the same `MapLibre` product. **The directory name matters**: SwiftPM
derives package identity from it, and the matching identity is what applies the
override to swiftui-dsl's transitive dependency too.
