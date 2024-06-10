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

  func testPlaceWithVenueID() throws {
    // Place Details (Fremont Troll)
    let url = URL(string: "https://maps.earth/place/openstreetmap%3Avenue%3Anode%2F2485251324")!
    let expected = UniversalLink.place(
      placeID: .venue(gid: "openstreetmap:venue:node/2485251324"))
    XCTAssertEqual(UniversalLink(url: url)!, expected)
  }

  func testPlaceWithLatLon() throws {
    // Place Details (Somewhere in Redmond)
    let url = URL(string: "https://maps.earth/place/-122.1,47.6")!
    let expected = UniversalLink.place(placeID: .lngLat(LngLat(lng: -122.1, lat: 47.6)))
    XCTAssertEqual(UniversalLink(url: url)!, expected)
  }

  func testDirectionsWithVenueIDs() throws {
    let url = URL(
      string:
        "https://maps.earth/directions/bicycle/openstreetmap%3Avenue%3Anode%2F2485251324/-122.1,47.6"
    )!
    let expected = UniversalLink.directions(
      travelMode: .bike,
      from: .lngLat(LngLat(lng: -122.1, lat: 47.6)),
      to: .venue(gid: "openstreetmap:venue:node/2485251324")
    )
    XCTAssertEqual(UniversalLink(url: url)!, expected)
  }

  func testDirectionsWithLonLat() throws {
    let url = URL(
      string:
        "https://maps.earth/directions/bicycle/openstreetmap%3Avenue%3Anode%2F2485251324/-122.1,47.6"
    )!
    let expected = UniversalLink.directions(
      travelMode: .bike,
      from: .lngLat(LngLat(lng: -122.1, lat: 47.6)),
      to: .venue(gid: "openstreetmap:venue:node/2485251324")
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
      to: .venue(gid: "openstreetmap:venue:node/2485251324")
    )
    XCTAssertEqual(UniversalLink(url: url)!, expected)
  }

  func testDirectionsNoDestination() throws {
    // Directions (Space Needle to unspecified place):
    let url = URL(
      string: "https://maps.earth/directions/bicycle/_/openstreetmap%3Avenue%3Away%2F12903132")!
    let expected = UniversalLink.directions(
      travelMode: .bike,
      from: .venue(gid: "openstreetmap:venue:way/12903132"),
      to: nil
    )
    XCTAssertEqual(UniversalLink(url: url)!, expected)
  }

  func testUrlForPlace() throws {
    // Note that the maps.earth web app unnecessarily escapes the ":" from the path portion. This distinction is insignificant.
    // It is significant, however, that they both escape the "/" between node and the node id
    let url = URL(string: "https://maps.earth/place/openstreetmap:venue:node%2F2485251324")!
    let link = UniversalLink(url: url)!
    XCTAssertEqual(url, link.url)
  }

  func testUrlForDirections() throws {
    let url = URL(string: "https://maps.earth/directions/bicycle/openstreetmap:venue:node%2F2485251324/-122.1,47.6")!
    let link = UniversalLink(url: url)!
    XCTAssertEqual(url, link.url)
  }

  func testUrlForDirectionsWithMissingFrom() throws {
    let url = URL(string: "https://maps.earth/directions/bicycle/openstreetmap:venue:node%2F2485251324/_")!
    let link = UniversalLink(url: url)!
    XCTAssertEqual(url, link.url)
  }
}
