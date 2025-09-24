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

    XCTAssertEqual(geometry.count, 291)

    do {
      let expected = CLLocationCoordinate2D(latitude: 47.563527, longitude: -122.37834)
      XCTAssertEqual(geometry[0].latitude, expected.latitude, accuracy: 10e-5)
      XCTAssertEqual(geometry[0].longitude, expected.longitude, accuracy: 10e-5)
    }

    do {
      let expected = CLLocationCoordinate2D(latitude: 47.5991, longitude: -122.3317)
      XCTAssertEqual(geometry[286].latitude, expected.latitude, accuracy: 10e-4)
      XCTAssertEqual(geometry[286].longitude, expected.longitude, accuracy: 10e-4)
    }
  }

  func testDuration() {
    let trip = FixtureData.bikeTrips[0]
    XCTAssertEqual(trip.duration, 2038.0, accuracy: 10e-3)
    XCTAssertEqual(trip.durationFormatted, "33 min")
  }

  func testDistance() {
    let trip = FixtureData.bikeTrips[0]
    XCTAssertEqual(trip.distance, 4.328, accuracy: 10e-3)
    XCTAssertEqual(trip.distanceUnit, .miles)
  }

  func testDistanceFormatting() {
    var trip = FixtureData.bikeTrips[0]
    trip._formatLocale = Locale(identifier: "en_US")
    XCTAssertEqual(trip.distanceFormatted, "4.3 miles")

    trip._formatLocale = Locale(identifier: "en_CA")
    XCTAssertEqual(trip.distanceFormatted, "7 kilometres")

    trip._formatLocale = Locale(identifier: "de_DE")
    XCTAssertEqual(trip.distanceFormatted, "7 Kilometer")

    trip._formatLocale = Locale(identifier: "en_GB")
    XCTAssertEqual(trip.distanceFormatted, "4.3 miles")
  }

  func testWalkManeuvers() {
    let trip = FixtureData.walkTrips[0]
    XCTAssertEqual(trip.duration, 5646.0, accuracy: 10e-3)
    XCTAssertEqual(trip.distance, 4.289, accuracy: 10e-3)
    XCTAssertEqual(trip.distanceUnit, .miles)

    XCTAssertEqual(trip.legs.count, 1)
    let leg = trip.legs[0]

    guard case .nonTransit(let nonTransitLeg) = leg.modeLeg else {
      fatalError("unexpeted mode leg")
    }
    let maneuvers = nonTransitLeg.maneuvers

    XCTAssertEqual(maneuvers.count, 25)
    let firstManeuver = maneuvers[0]
    XCTAssertEqual(firstManeuver.type, .start)
    XCTAssertEqual(firstManeuver.instruction, "Walk northeast on sidewalk.")
    XCTAssertEqual(firstManeuver.verbalPostTransitionInstruction, "Continue for 300 feet.")

    let lastManeuver = maneuvers.last!
    XCTAssertEqual(lastManeuver.type, .destination)
    XCTAssertEqual(lastManeuver.instruction, "Arrive at your destination.")
    XCTAssertEqual(lastManeuver.verbalPostTransitionInstruction, nil)
  }

  func testErrorResponse() {
    let tripError = FixtureData.bikeTripError
    XCTAssertEqual(tripError.errorCode, TripPlanErrorCode(rawValue: 2154))
  }
}
