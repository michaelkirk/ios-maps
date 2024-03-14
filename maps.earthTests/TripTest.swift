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

    XCTAssertEqual(geometry.count, 288)

    do {
      let expected = CLLocationCoordinate2D(latitude: 47.599212, longitude: -122.331855)
      XCTAssertEqual(geometry[0].latitude, expected.latitude, accuracy: 10e-5)
      XCTAssertEqual(geometry[0].longitude, expected.longitude, accuracy: 10e-5)
    }

    do {
      let expected = CLLocationCoordinate2D(latitude: 47.563527, longitude: -122.378442)
      XCTAssertEqual(geometry[287].latitude, expected.latitude, accuracy: 10e-5)
      XCTAssertEqual(geometry[287].longitude, expected.longitude, accuracy: 10e-5)
    }
  }

  func testDuration() {
    let trip = FixtureData.bikeTrips[0]
    XCTAssertEqual(trip.duration, 1575.005, accuracy: 10e-3)
    XCTAssertEqual(trip.durationFormatted, "26 min")
  }

  func testDistance() {
    let trip = FixtureData.bikeTrips[0]
    XCTAssertEqual(trip.distance, 4.374, accuracy: 10e-3)
    XCTAssertEqual(trip.distanceUnit, .miles)
  }

  func testDistanceFormatting() {
    var trip = FixtureData.bikeTrips[0]
    trip._formatLocale = Locale(identifier: "en_US")
    XCTAssertEqual(trip.distanceFormatted, "4.4 miles")

    trip._formatLocale = Locale(identifier: "en_CA")
    XCTAssertEqual(trip.distanceFormatted, "7 kilometres")

    trip._formatLocale = Locale(identifier: "de_DE")
    XCTAssertEqual(trip.distanceFormatted, "7 Kilometer")

    trip._formatLocale = Locale(identifier: "en_GB")
    XCTAssertEqual(trip.distanceFormatted, "4.4 miles")
  }
}
