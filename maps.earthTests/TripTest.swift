//
//  TripTest.swift
//  maps.earthTests
//
//  Created by Michael Kirk on 3/4/24.
//

import CoreLocation
import XCTest

@testable import maps_earth

final class TripTest: XCTestCase {
  func testGeometry() throws {
    let trip = FixtureData.bike_trips[0]
    let geometry = trip.legs[0].geometry

    XCTAssertEqual(geometry.count, 427)

    do {
      let expected = CLLocationCoordinate2D(latitude: 47.651048, longitude: -122.34732)
      XCTAssertEqual(geometry[0].latitude, expected.latitude, accuracy: 10e-5)
      XCTAssertEqual(geometry[0].longitude, expected.longitude, accuracy: 10e-5)
    }

    do {
      let expected = CLLocationCoordinate2D(latitude: 47.598943, longitude: -122.336074)
      XCTAssertEqual(geometry[349].latitude, expected.latitude, accuracy: 10e-5)
      XCTAssertEqual(geometry[349].longitude, expected.longitude, accuracy: 10e-5)
    }
  }
}
