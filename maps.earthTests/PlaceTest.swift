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

  func testVariousRectangles() {
    let bbox = BBox(top: 89, right: 179, bottom: -90, left: -179)
    let bounds = Bounds(bbox: bbox)
    XCTAssertEqual(bbox.max, bounds.max)
    XCTAssertEqual(bbox.min, bounds.min)

    let mlnBounds = bounds.mlnBounds
    XCTAssertEqual(mlnBounds.ne, bounds.max.asCoordinate)
    XCTAssertEqual(mlnBounds.sw, bounds.min.asCoordinate)
  }
}
