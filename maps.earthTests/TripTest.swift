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
    let trip = FixtureData.bikeTrips[1]
    let geometry = trip.legs[0].geometry

    XCTAssertEqual(geometry.count, 287)

    do {
      let expected = CLLocationCoordinate2D(latitude: 47.563527, longitude: -122.378442)
      XCTAssertEqual(geometry[0].latitude, expected.latitude, accuracy: 10e-5)
      XCTAssertEqual(geometry[0].longitude, expected.longitude, accuracy: 10e-5)
    }

    do {
      let expected = CLLocationCoordinate2D(latitude: 47.599212, longitude: -122.331855)
      XCTAssertEqual(geometry[286].latitude, expected.latitude, accuracy: 10e-5)
      XCTAssertEqual(geometry[286].longitude, expected.longitude, accuracy: 10e-5)
    }
  }

  func testDuration() {
    let trip = FixtureData.bikeTrips[1]
    XCTAssertEqual(trip.duration, 1566.205, accuracy: 10e-3)
    XCTAssertEqual(trip.durationFormatted, "26 min")
  }

  func testDistance() {
    let trip = FixtureData.bikeTrips[1]
    XCTAssertEqual(trip.distance, 4.358, accuracy: 10e-3)
    XCTAssertEqual(trip.distanceUnit, .miles)
  }

  func testDistanceFormatting() {
    var trip = FixtureData.bikeTrips[1]
    trip._formatLocale = Locale(identifier: "en_US")
    XCTAssertEqual(trip.distanceFormatted, "4.4 miles")

    trip._formatLocale = Locale(identifier: "en_CA")
    XCTAssertEqual(trip.distanceFormatted, "7 kilometres")

    trip._formatLocale = Locale(identifier: "de_DE")
    XCTAssertEqual(trip.distanceFormatted, "7 Kilometer")

    trip._formatLocale = Locale(identifier: "en_GB")
    XCTAssertEqual(trip.distanceFormatted, "4.4 miles")
  }

  func testWalkManeuvers() {
    let trip = FixtureData.walkTrips[1]
    XCTAssertEqual(trip.duration, 4025.249, accuracy: 10e-3)
    XCTAssertEqual(trip.distance, 4.736, accuracy: 10e-3)
    XCTAssertEqual(trip.distanceUnit, .miles)

    XCTAssertEqual(trip.legs.count, 1)
    let leg = trip.legs[0]

    guard case .nonTransit(let nonTransitLeg) = leg.modeLeg else {
      fatalError("unexpeted mode leg")
    }
    let maneuvers = nonTransitLeg.maneuvers

    XCTAssertEqual(maneuvers.count, 39)
    let firstManeuver = maneuvers[0]
    XCTAssertEqual(firstManeuver.type, .startLeft)
    XCTAssertEqual(firstManeuver.instruction, "Walk southwest on the walkway.")
    XCTAssertEqual(firstManeuver.verbalPostTransitionInstruction, "Continue for 100 feet.")

    let lastManeuver = maneuvers.last!
    XCTAssertEqual(lastManeuver.type, .destination)
    XCTAssertEqual(lastManeuver.instruction, "You have arrived at your destination.")
    XCTAssertEqual(lastManeuver.verbalPostTransitionInstruction, nil)
  }

  func testErrorResponse() {
    let tripError = FixtureData.bikeTripError
    XCTAssertEqual(tripError.errorCode, TripPlanErrorCode(rawValue: 2154))
  }
}
