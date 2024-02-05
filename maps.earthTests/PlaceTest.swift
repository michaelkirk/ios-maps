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
    let place = FixtureData.places[0]
    XCTAssertEqual(place.name, "Schoolhouse Coffee")
    XCTAssertEqual(place.location, LngLat(lng: -122.754113, lat: 47.079458))
  }
}
