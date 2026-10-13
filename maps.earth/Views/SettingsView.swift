import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var preferences: Preferences
  @State private var navigateToOfflineMaps = false
  var initiallyShowOfflineMaps: Bool = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          NavigationLink(destination: AboutView()) {
            Label("About Maps.Earth", systemImage: "info.circle")
          }
          NavigationLink(destination: AttributionsView()) {
            Label("Attributions", systemImage: "heart")
          }
        }

        Section {
          Toggle(
            isOn: Binding(
              get: { preferences.devMode },
              set: { newValue in
                Task {
                  await preferences.setDevMode(newValue)
                }
              }
            )
          ) {
            Label("Developer Mode", systemImage: "hammer")
          }
          Toggle(
            isOn: Binding(
              get: { preferences.offlineMapFeatureEnabled },
              set: { newValue in
                Task {
                  await preferences.setOfflineMapFeatureEnabled(newValue)
                  // If enabling the feature, download the overview map
                  if newValue {
                    _ = await OfflineRegionManager.downloadOverviewMap()
                  }
                  // If disabling the feature, also disable offline mode
                  if !newValue && preferences.offlineMode {
                    await preferences.setOfflineMode(false)
                  }
                }
              }
            )
          ) {
            Label("Offline Maps Feature (Beta)", systemImage: "map")
          }
        } header: {
          Text("Experimental Features")
        } footer: {
          Text(
            "Enable offline map downloads. This feature is experimental. Downloaded maps are not yet fully offline and require an internet connection for searching and routing."
          )
        }

        if preferences.offlineMapFeatureEnabled {
          Section {
            Toggle(
              isOn: Binding(
                get: { preferences.offlineMode },
                set: { newValue in
                  Task {
                    await preferences.setOfflineMode(newValue)
                  }
                }
              )
            ) {
              Label("Go Offline", systemImage: preferences.offlineMode ? "icloud.slash" : "icloud")
            }
          } header: {
            Text("Map Data")
          } footer: {
            Text("Use downloaded maps instead of fetching from the server")
          }

          Section {
            NavigationLink(destination: OfflineMapsView()) {
              Label("Offline Maps", systemImage: "arrow.down.circle")
            }
          }
        }
      }
      .navigationDestination(isPresented: $navigateToOfflineMaps) {
        OfflineMapsView()
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
      .onAppear {
        if initiallyShowOfflineMaps {
          navigateToOfflineMaps = true
        }
      }
    }
  }
}

struct AboutView: View {
  var body: some View {
    ScrollView {
      AppInfoSheetContents()
    }
    .navigationTitle("About")
    .navigationBarTitleDisplayMode(.inline)
  }
}

/// Thanks the open data and open source projects the app is built on.
struct AttributionsView: View {
  struct Credit: Identifiable {
    let name: String
    let url: URL
    let thanks: String
    var id: String { name }
  }

  struct Group: Identifiable {
    let title: String
    let credits: [Credit]
    var id: String { title }
  }

  static let groups: [Group] = [
    Group(
      title: "Map data",
      credits: [
        Credit(
          name: "OpenStreetMap", url: URL(string: "https://www.openstreetmap.org/copyright")!,
          thanks:
            "The roads, paths, buildings, and places on this map, built by millions of contributors. © OpenStreetMap contributors."
        ),
        Credit(
          name: "Natural Earth", url: URL(string: "https://www.naturalearthdata.com")!,
          thanks: "Public domain coastlines and boundaries for the zoomed-out map."),
        Credit(
          name: "Who's On First", url: URL(string: "https://whosonfirst.org")!,
          thanks: "The gazetteer of places behind search."),
        Credit(
          name: "OpenAddresses", url: URL(string: "https://openaddresses.io")!,
          thanks: "Address points that help search find where you mean."),
        Credit(
          name: "Transitland Atlas",
          url: URL(string: "https://github.com/transitland/transitland-atlas")!,
          thanks:
            "A catalog of transit feeds, and the transit agencies who publish their schedules and realtime data openly."
        ),
      ]),
    Group(
      title: "Building and serving the map",
      credits: [
        Credit(
          name: "Headway", url: URL(string: "https://github.com/headwaymaps/headway")!,
          thanks: "The open source map stack behind this app's maps, search, and directions."),
        Credit(
          name: "Planetiler", url: URL(string: "https://github.com/onthegomap/planetiler")!,
          thanks: "Turns the whole planet into map tiles."),
        Credit(
          name: "OpenMapTiles", url: URL(string: "https://openmaptiles.org")!,
          thanks: "The vector tile schema our map is drawn from."),
        Credit(
          name: "Martin", url: URL(string: "https://martin.maplibre.org")!,
          thanks: "Serves the map tiles."),
        Credit(
          name: "Valhalla", url: URL(string: "https://github.com/valhalla/valhalla")!,
          thanks: "Driving, biking, and walking directions."),
        Credit(
          name: "OpenTripPlanner", url: URL(string: "https://www.opentripplanner.org")!,
          thanks: "Transit directions."),
        Credit(
          name: "Pelias", url: URL(string: "https://pelias.io")!,
          thanks: "Search and reverse geocoding, with help from libpostal."),
      ]),
    Group(
      title: "How the map looks",
      credits: [
        Credit(
          name: "OpenStreetMap Americana",
          url: URL(string: "https://github.com/osm-americana/openstreetmap-americana")!,
          thanks: "Highway shields, and a lot of inspiration."),
        Credit(
          name: "OSM Liberty", url: URL(string: "https://github.com/maputnik/osm-liberty")!,
          thanks: "The map style we started from."),
        Credit(
          name: "Maki", url: URL(string: "https://github.com/mapbox/maki")!,
          thanks: "Points of interest icons."),
        Credit(
          name: "Roboto and Overpass", url: URL(string: "https://fonts.google.com")!,
          thanks: "The typefaces for map labels."),
      ]),
    Group(
      title: "This app",
      credits: [
        Credit(
          name: "MapLibre Native", url: URL(string: "https://maplibre.org")!,
          thanks: "Draws the map on your phone."),
        Credit(
          name: "Ferrostar", url: URL(string: "https://github.com/stadiamaps/ferrostar")!,
          thanks: "Turn-by-turn navigation."),
      ]),
  ]

  var body: some View {
    List {
      Section {
        Text(
          "Maps.Earth is mostly other people's work, stitched together. We're grateful to everyone who builds and shares the open data and open source software that make it possible."
        )
      }
      ForEach(Self.groups) { group in
        Section(group.title) {
          ForEach(group.credits) { credit in
            Link(destination: credit.url) {
              VStack(alignment: .leading, spacing: Space.xs) {
                Text(credit.name).hwText(.heading)
                Text(credit.thanks).hwText(.secondary)
              }
            }
          }
        }
      }
      Section("And many more") {
        Text(
          "Beyond these are hundreds of smaller libraries, tools, and data sets that each make something here a little nicer. Thank you to all of their authors and maintainers."
        )
      }
    }
    .navigationTitle("Attributions")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview("Attributions") {
  NavigationView {
    AttributionsView()
  }
}

#Preview("Settings") {
  SettingsView()
    .environmentObject(Preferences.forTesting())
}

#Preview("About") {
  NavigationView {
    AboutView()
  }
}
