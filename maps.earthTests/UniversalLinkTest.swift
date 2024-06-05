//
//  UniversalLinkTest.swift
//  maps.earthTests
//
//  Created by Michael Kirk on 6/4/24.
//

import XCTest

@testable import maps_earth

final class UniversalLinkTest: XCTestCase {
  func testRoot() throws {
    do {
      let url = URL(string: "https://maps.earth")!
      XCTAssertEqual(UniversalLink(url: url)!, .home)
    }

    do {
      let url = URL(string: "https://maps.earth/")!
      XCTAssertEqual(UniversalLink(url: url)!, .home)
    }
  }

  func testPlace() throws {
    // Place Details (Fremont Troll)
    let url = URL(string: "https://maps.earth/place/openstreetmap%3Avenue%3Anode%2F2485251324")!
    let expected = UniversalLink.place(
      placeID: PlaceID(source: "openstreetmap:venue:node", id: 2_485_251_324))
    XCTAssertEqual(UniversalLink(url: url)!, expected)
  }

  func testDirections() throws {
    // Directions (Space Needle to Fremont Troll):
    let url = URL(
      string:
        "https://maps.earth/directions/bicycle/openstreetmap%3Avenue%3Anode%2F2485251324/openstreetmap%3Avenue%3Away%2F12903132"
    )!
    let expected = UniversalLink.directions(
      travelMode: .bike,
      from: PlaceID(source: "openstreetmap:venue:way", id: 12_903_132),
      to: PlaceID(source: "openstreetmap:venue:node", id: 2_485_251_324)
    )
    XCTAssertEqual(UniversalLink(url: url)!, expected)
  }

  func testDirectionsNoOrigin() throws {
    // Directions (unspecified place to Fremont Troll):
    let url = URL(
      string: "https://maps.earth/directions/bicycle/openstreetmap%3Avenue%3Anode%2F2485251324/_")!
    let expected = UniversalLink.directions(
      travelMode: .bike,
      from: nil,
      to: PlaceID(source: "openstreetmap:venue:node", id: 2_485_251_324)
    )
    XCTAssertEqual(UniversalLink(url: url)!, expected)
  }

  func testDirectionsNoDestination() throws {
    // Directions (Space Needle to unspecified place):
    let url = URL(
      string: "https://maps.earth/directions/bicycle/_/openstreetmap%3Avenue%3Away%2F12903132")!
    let expected = UniversalLink.directions(
      travelMode: .bike,
      from: PlaceID(source: "openstreetmap:venue:way", id: 12_903_132),
      to: nil
    )
    XCTAssertEqual(UniversalLink(url: url)!, expected)
  }
}
