fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build

```sh
[bundle exec] fastlane ios build
```

Compile for the simulator, a faster check than a full archive

### ios archive

```sh
[bundle exec] fastlane ios archive
```

Archive the app, without touching versions or git

### ios cut_alpha

```sh
[bundle exec] fastlane ios cut_alpha
```

Bump build (or minor version with bump_version:true), archive, and tag an alpha

### ios tag_alpha

```sh
[bundle exec] fastlane ios tag_alpha
```

Tag current version as alpha (e.g. v1.14.alpha2)

### ios tag_beta

```sh
[bundle exec] fastlane ios tag_beta
```

Tag current version as beta (e.g. v1.14.beta2)

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Upload most recent build to App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
