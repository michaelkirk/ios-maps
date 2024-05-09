To override a SwiftPM dependency for local editing:

    git submodule add https://github.com/flitsmeister/mapbox-directions-swift DevDependencies/mapbox-directions-swift

Then open DevDependencies in Finder and drag the mapbox-directions-swit directory into Xcode (might as well put it under the DevDependencies group, but I don't think it matters)

Be sure to check "add to target: maps.earth"

You should see your SPM installed dependency disappear.

You can commit these changes while you're working on your branch, but you
probably want to revert them once the changes to the your forked dependency
have been upstreamed.

