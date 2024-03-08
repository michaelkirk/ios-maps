//
//  PlaceTest.swift
//  maps.earthTests
//
//  Created by Michael Kirk on 2/6/24.
//

import XCTest

@testable import maps_earth

final class PlaceTest: XCTestCase {
  func testParsing() throws {
    let place = FixtureData.places[.zeitgeist]
    XCTAssertEqual(place.name, "Zeitgeist Coffee")
    XCTAssertEqual(place.location, LngLat(lng: -122.331856, lat: 47.599091))
  }
}
