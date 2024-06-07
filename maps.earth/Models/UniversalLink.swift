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
    var components = url.pathComponents.makeIterator()

    guard let root = components.next() else {
      self = .home
      return
    }
    assert(root == "/")

    switch components.next() {
    case nil:
      self = .home
    case "place":
      guard let placeID = PlaceID(pathComponents: &components) else {
        assertionFailure("no handler for URL: \(url)")
        return nil
      }
      // TODO: Once we support long-press to highlight, don't do a geocode at all and just open the details page for that exact coord?
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
}
