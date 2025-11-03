import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var preferences: Preferences
  @State private var navigateToOfflineMaps = false
  var initiallyShowOfflineMaps: Bool = false

  var body: some View {
    NavigationView {
      List {
        Section {
          NavigationLink(destination: AboutView()) {
            Label("About Maps.Earth", systemImage: "info.circle")
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
                    await OfflineRegionManager.downloadOverviewMap()
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
            NavigationLink(
              destination: OfflineMapsView(),
              isActive: $navigateToOfflineMaps
            ) {
              Label("Offline Maps", systemImage: "arrow.down.circle")
            }
          }
        }
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

#Preview("Settings") {
  SettingsView()
    .environmentObject(Preferences.forTesting())
}

#Preview("About") {
  NavigationView {
    AboutView()
  }
}
