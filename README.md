# Maps built on Open Data for iOS

Maps.Earth is a maps app for iOS, get it on the AppStore at <https://apps.apple.com/us/app/maps-earth/id6479329515>.

A web version is available at <https://www.maps.earth>.

Both are powered by [Headway](https://github.com/headwaymaps/headway), an open source self-hosted map stack based on OpenStreetMap and other open projects.

## Development

### Pointing the app at a non-default backend

Backend endpoints are configured in [`maps.earth/Utils/AppConfig.swift`](maps.earth/Utils/AppConfig.swift).
To point a simulator (or device) build at a different backend, edit `onlineServerBase`:

If you're pointing at a cleartext (`http://`) endpoint, you may need to add an
App Transport Security exception in `Info.plist`. Cleartext to `localhost` is
permitted by default on the iOS simulator but not on a physical device.

