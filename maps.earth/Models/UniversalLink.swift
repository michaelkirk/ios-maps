//
//  UniversalLink.swift
//  maps.earth
//
//  Created by Michael Kirk on 6/4/24.
//

import Foundation

// Place Details (Fremont Troll): https://maps.earth/place/openstreetmap%3Avenue%3Anode%2F2485251324
// Directions (Space Needle to Fremont Troll): https://maps.earth/directions/bicycle/openstreetmap%3Avenue%3Anode%2F2485251324/openstreetmap%3Avenue%3Away%2F12903132
// Map Viewport (Seattle): https://maps.earth/#map=12/47.6/-122.3
enum UniversalLink: Equatable {
  case home(viewport: MapViewport?)
  case place(placeID: PlaceID)
  case directions(travelMode: TravelMode, from: PlaceID?, to: PlaceID?)

  init?(url: URL) {
    // Don't use `url.pathComponents` because it unnecessarily escapes the %2F (slash) in the PlaceID, causing the PlaceID to span two path components when a slash is present in the ID. Which it only is some of the times (e.g. polyline IDs contain no slash)
    var components = url.path().split(separator: "/").map { $0.removingPercentEncoding! }
      .makeIterator()

    switch components.next() {
    case nil:
      self = .home(viewport: url.fragment().flatMap(MapViewport.init(urlFragment:)))
    case "place":
      guard let placeID = PlaceID(pathComponents: &components) else {
        assertionFailure("no handler for URL: \(url)")
        return nil
      }
      self = .place(placeID: placeID)
    case "directions":
      guard let travelModeString = components.next() else {
        assertionFailure("travelModeString was unexpectedly nil")
        return nil
      }
      guard let travelMode = TravelMode(rawValue: travelModeString.uppercased()) else {
        assertionFailure("invalid travelModeString: \(travelModeString)")
        return nil
      }

      let to = PlaceID(pathComponents: &components)
      let from = PlaceID(pathComponents: &components)
      assert(to != nil || from != nil, "expecting at least one of to/from set")
      self = .directions(travelMode: travelMode, from: from, to: to)
    default:
      assertionFailure("no handler for URL: \(url)")
      return nil
    }
  }

  var url: URL {
    switch self {
    case .home(let viewport):
      if let viewport {
        URL(string: "/#\(viewport.urlFragment)", relativeTo: AppConfig().onlineServerBase)!
          .absoluteURL
      } else {
        AppConfig().onlineServerBase
      }
    case .place(let placeID):
      AppConfig().onlineServerBase
        .appending(component: "place")
        .appending(component: placeID.serialized)
    case .directions(let travelMode, let from, let to):
      AppConfig().onlineServerBase
        .appending(component: "directions")
        .appending(component: travelMode.rawValue.lowercased())
        .appending(component: to?.serialized ?? "_")
        .appending(component: from?.serialized ?? "_")
    }
  }
}

/// The map position www keeps in its URL as `#map=zoom/lat/lng[/bearing[/pitch]]`.
struct MapViewport: Equatable {
  var center: LngLat
  var zoom: Double
  var bearing: Double = 0
  var pitch: Double = 0
}

extension MapViewport {
  init?(urlFragment: String) {
    guard
      let value = urlFragment.split(separator: "&")
        .first(where: { $0.hasPrefix("map=") })?
        .dropFirst("map=".count)
    else {
      return nil
    }
    let parts = value.split(separator: "/")
    let n = parts.compactMap { Double($0) }
    guard n.count == parts.count, (3...5).contains(n.count) else {
      return nil
    }
    self.init(
      center: LngLat(lng: n[2], lat: n[1]), zoom: n[0], bearing: n.count > 3 ? n[3] : 0,
      pitch: n.count > 4 ? n[4] : 0)
  }

  var urlFragment: String {
    var parts = [zoom, center.lat, center.lng]
    if bearing != 0 || pitch != 0 { parts.append(bearing) }
    if pitch != 0 { parts.append(pitch) }
    return "map="
      + parts.map { $0 == $0.rounded() ? String(Int($0)) : String($0) }.joined(separator: "/")
  }
}
