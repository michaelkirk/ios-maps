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
      guard let placeSource = components.next() else {
        assertionFailure("no handler for URL: \(url)")
        return nil
      }
      guard let placeSourceID = components.next() else {
        assertionFailure("no handler for URL: \(url)")
        return nil
      }
      guard let id = UInt64(placeSourceID) else {
        assertionFailure("invalid non-numeric place id")
        return nil
      }
      self = .place(placeID: PlaceID(source: placeSource, id: id))
    case "directions":
      guard let travelModeString = components.next() else {
        assertionFailure("travelModeString was unexpectedly nil")
        return nil
      }
      guard let travelMode = TravelMode(rawValue: travelModeString.uppercased()) else {
        assertionFailure("invalid travelModeString: \(travelModeString)")
        return nil
      }

      var to: PlaceID?
      guard let toSourceID = components.next() else {
        assertionFailure("missing 'to' component in directions URL")
        return nil
      }
      if toSourceID == "_" {
        to = nil
      } else {
        guard let placeSourceID = components.next() else {
          assertionFailure("missing numeric portion of place 'to' id")
          return nil
        }
        guard let id = UInt64(placeSourceID) else {
          assertionFailure("invalid non-numeric place 'to' id")
          return nil
        }
        to = PlaceID(source: toSourceID, id: id)
      }

      var from: PlaceID?
      guard let fromSourceID = components.next() else {
        assertionFailure("missing 'from' component in directions URL")
        return nil
      }
      if fromSourceID == "_" {
        from = nil
      } else {
        guard let placeSourceID = components.next() else {
          assertionFailure("missing numeric portion of place 'from' id")
          return nil
        }
        guard let id = UInt64(placeSourceID) else {
          assertionFailure("invalid non-numeric place 'from' id")
          return nil
        }
        from = PlaceID(source: fromSourceID, id: id)
      }

      self = .directions(travelMode: travelMode, from: from, to: to)
    default:
      assertionFailure("no handler for URL: \(url)")
      return nil
    }
  }
}
