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
  func testGeometry() {
    let trip = FixtureData.bikeTrips[0]
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

  func testDuration() {
    let trip = FixtureData.bikeTrips[0]
    XCTAssertEqual(trip.duration, 2220.392, accuracy: 10e-3)
    XCTAssertEqual(trip.durationFormatted, "37 min")
  }

  func testDistance() {
    let trip = FixtureData.bikeTrips[0]
    XCTAssertEqual(trip.distance, 6.178, accuracy: 10e-3)
    XCTAssertEqual(trip.distanceFormatUnit, .mile)
    XCTAssertEqual(trip.distanceFormatted, "6.2 miles")
  }
}
