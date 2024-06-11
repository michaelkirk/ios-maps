//
//  UniversalLink.swift
//  maps.earth
//
//  Created by Michael Kirk on 6/4/24.
//

import Foundation

// Place Details (Fremont Troll): https://maps.earth/place/openstreetmap%3Avenue%3Anode%2F2485251324
// Directions (Space Needle to Fremont Troll): https://maps.earth/directions/bicycle/openstreetmap%3Avenue%3Anode%2F2485251324/openstreetmap%3Avenue%3Away%2F12903132
enum UniversalLink: Equatable {
  case home
  case place(placeID: PlaceID)
  case directions(travelMode: TravelMode, from: PlaceID?, to: PlaceID?)

  init?(url: URL) {
    // Don't use `url.pathComponents` because it unnecessarily escapes the %2F (slash) in the PlaceID, causing the PlaceID to span two path components when a slash is present in the ID. Which it only is some of the times (e.g. polyline IDs contain no slash)
    var components = url.path().split(separator: "/").map { $0.removingPercentEncoding! }.makeIterator()

    switch components.next() {
    case nil:
      self = .home
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
    case .home:
      AppConfig().serverBase
    case .place(placeID: let placeID):
      AppConfig().serverBase
        .appending(component: "place")
        .appending(component: placeID.serialized)
    case .directions(travelMode: let travelMode, from: let from, to: let to):
      AppConfig().serverBase
        .appending(component: "directions")
        .appending(component: travelMode.rawValue.lowercased())
        .appending(component: to?.serialized ?? "_")
        .appending(component: from?.serialized ?? "_")
    }
  }
}
