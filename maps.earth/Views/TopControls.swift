//
//  TopControls.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/20/24.
//

import MapLibre
import SwiftUI

private let logger = FileLogger()

struct TopControls: View {
  @Binding var pendingMapFocus: MapFocus?
  static let controlHeight: CGFloat = 38

  @EnvironmentObject var preferences: Preferences

  var body: some View {
    VStack(spacing: 0) {
      SettingsButton()
        .frame(width: Self.controlHeight, height: Self.controlHeight)
      Divider()
      LocateMeButton(pendingMapFocus: $pendingMapFocus)
        .frame(width: Self.controlHeight, height: Self.controlHeight)
      if preferences.offlineMapFeatureEnabled {
        Divider()
        OfflineModeToggleButton()
          .frame(width: Self.controlHeight, height: Self.controlHeight)
      }
      if preferences.devMode {
        Divider()
        ZoomInButton()
          .frame(width: Self.controlHeight, height: Self.controlHeight)
        Divider()
        ZoomLevelDisplay()
        Divider()
        ZoomOutButton()
          .frame(width: Self.controlHeight, height: Self.controlHeight)
        Divider()
        ClearCacheButton()
          .frame(width: Self.controlHeight, height: Self.controlHeight)
      }
    }
    .imageScale(.medium)
    .tint(Color.hw_sheetCloseForeground)

    .background(Color.hw_sheetBackground)
    .cornerRadius(8)
    .shadow(radius: 3)
  }
}

struct SettingsButton: View {
  @State var showingSettings: Bool = false

  var body: some View {
    Button(action: {
      showingSettings = true
    }) {
      Image(systemName: "gearshape")
    }.sheet(isPresented: $showingSettings) {
      SettingsView()
    }
  }
}

struct OfflineModeToggleButton: View {
  @EnvironmentObject var preferences: Preferences

  var body: some View {
    Button(action: {
      Task {
        await preferences.setOfflineMode(!preferences.offlineMode)
      }
    }) {
      Image(systemName: preferences.offlineMode ? "icloud.slash" : "icloud")
    }
  }
}

struct ZoomInButton: View {
  var body: some View {
    Button(action: {
      guard let mapView = Env.current.getMapView() else { return }
      mapView.setZoomLevel(mapView.zoomLevel + 1, animated: true)
    }) {
      Image(systemName: "plus")
    }
  }
}

struct ZoomLevelDisplay: View {
  @State private var zoomLevel: Double = 0
  let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

  var body: some View {
    Text(zoomLevel > 0 ? String(format: "%.1f", zoomLevel) : "?")
      .font(.system(size: 12, weight: .medium, design: .monospaced))
      .frame(width: TopControls.controlHeight, height: TopControls.controlHeight)
      .onReceive(timer) { _ in
        guard let mapView = Env.current.getMapView() else { return }
        zoomLevel = mapView.zoomLevel
      }
  }
}

struct ZoomOutButton: View {
  var body: some View {
    Button(action: {
      guard let mapView = Env.current.getMapView() else { return }
      mapView.setZoomLevel(mapView.zoomLevel - 1, animated: true)
    }) {
      Image(systemName: "minus")
        .frame(width: TopControls.controlHeight, height: TopControls.controlHeight)
    }
  }
}

struct ClearCacheButton: View {
  var body: some View {
    Button(action: {
      Task {
        Env.current.getMapView()!.reloadStyle(nil)
        do {
          try await MLNOfflineStorage.shared.resetDatabase()
          try await MLNOfflineStorage.shared.clearAmbientCacheWithLogging(
            context: "manual button press")
        } catch {
          logger.error("Error while clearing map cache: \(error)")
        }
      }
    }) {
      Image(systemName: "trash")
    }
  }
}

extension AttributedString {
  mutating func linkify(rangeOf match: String, url: URL) {
    if let range = self.range(of: match) {
      let linkAttribute = AttributeContainer.link(url)
      self[range].mergeAttributes(linkAttribute)
    } else {
      assertionFailure("missing link text")
    }
  }
}

struct AppInfoSheetContents: View {

  var p1: AttributedString {
    var string = AttributedString(
      "This app is built on open source. Learn more at about.maps.earth")
    string.linkify(rangeOf: "about.maps.earth", url: URL(string: "https://about.maps.earth")!)
    return string
  }

  var p2: AttributedString {
    var string = AttributedString(
      "The services this app needs to function, such as routing, geo search, and the \"tiles\" used to render the map itself, are all built and provided by Headway — an open source self-hostable map stack."
    )
    string.linkify(rangeOf: "Headway", url: URL(string: "https://github.com/headwaymaps/headway")!)
    return string
  }

  var p3: AttributedString {
    var string = AttributedString(
      "Map data is sourced from OpenStreetMap, Daylight, OpenAddresses, OpenMapTiles, \"Who's On First\", and Natural Earth."
    )

    string.linkify(rangeOf: "OpenStreetMap", url: URL(string: "https://www.openstreetmap.org")!)
    string.linkify(rangeOf: "Daylight", url: URL(string: "https://daylightmap.org")!)
    string.linkify(rangeOf: "OpenMapTiles", url: URL(string: "https://www.openmaptiles.org")!)
    string.linkify(rangeOf: "OpenAddresses", url: URL(string: "https://www.openaddresses.io")!)
    string.linkify(rangeOf: "\"Who's On First\"", url: URL(string: "https://whosonfirst.org")!)
    string.linkify(rangeOf: "Natural Earth", url: URL(string: "https://www.naturalearthdata.com")!)

    return string
  }

  var p4: AttributedString {
    var string = AttributedString("😍Happy? 🤬Angry? 🤔Curious?\n\n✉️ info@maps.earth")
    string.linkify(rangeOf: "info@maps.earth", url: URL(string: "mailto:info@maps.earth")!)
    return string
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(p1)
      Text(p2)
      Text(p3)
    }
    .padding()
    Text(p4).multilineTextAlignment(.center).bold().padding(.top)
  }
}

#Preview("Controls") {
  TopControls(pendingMapFocus: .constant(nil))
}
#Preview("App Info") {
  AppInfoSheetContents()
}
