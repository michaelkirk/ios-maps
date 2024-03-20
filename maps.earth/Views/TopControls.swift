//
//  TopControls.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/20/24.
//

import SwiftUI

struct TopControls: View {
  @Binding var userLocationState: UserLocationState
  @Binding var pendingMapFocus: MapFocus?
  static let controlHeight: CGFloat = 38

  var body: some View {
    VStack(spacing: 0) {
      AppInfoButton()
        .frame(width: Self.controlHeight, height: Self.controlHeight)
      Divider()
      LocateMeButton(state: $userLocationState, pendingMapFocus: $pendingMapFocus)
        .frame(width: Self.controlHeight, height: Self.controlHeight)
    }
    .imageScale(.medium)
    .tint(Color.hw_sheetCloseForeground)

    .background(Color.hw_sheetBackground)
    .cornerRadius(8)
    .shadow(radius: 3)
  }
}

struct AppInfoButton: View {
  @State var showingSheet: Bool = false
  var body: some View {
    Button(action: {
      showingSheet = true
    }) {
      Image(systemName: "info.circle")
    }.sheet(isPresented: $showingSheet) {
      SheetContents(
        title: "About", onClose: { showingSheet = false }, presentationDetents: [.large],
        currentDetent: .constant(.large)
      ) {
        AppInfoSheetContents()
        Spacer()
      }
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
  TopControls(userLocationState: .constant(.following), pendingMapFocus: .constant(nil))
}
#Preview("App Info") {
  AppInfoSheetContents()
}
