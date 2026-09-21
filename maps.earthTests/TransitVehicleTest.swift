//
//  TransitVehicleTest.swift
//  maps.earthTests
//
//  Created by Michael Kirk on 9/17/26.
//

import XCTest

@testable import maps_earth

final class TransitVehicleTest: XCTestCase {
  /// When the vehicle reported, which is also where its track begins.
  let reportedAt = Date(timeIntervalSince1970: 1_000_000)

  /// Three points, 10 seconds apart, heading north.
  func vehicle(withTrack: Bool) -> TransitVehicle {
    let track = VehicleTrack(
      stepSeconds: 10,
      points: [
        LngLat(lng: -122.0, lat: 47.0),
        LngLat(lng: -122.0, lat: 47.1),
        LngLat(lng: -122.0, lat: 47.3),
      ])
    return TransitVehicle(
      id: "vehicle-1",
      patternCode: "pattern-1",
      route: TransitRoute(shortName: "5", longName: nil, color: "FDB71A"),
      vehicleMode: .bus,
      headsign: "Shoreline Greenwood",
      vehicleId: "f-c23-metrokingcounty:8293",
      label: "8293",
      position: LonLatPair(LngLat(lng: -122.5, lat: 47.5)),
      lastUpdated: reportedAt,
      track: withTrack ? track : nil)
  }

  func testLocationBetweenPoints() {
    let vehicle = self.vehicle(withTrack: true)

    let quarterPastFirstStep = vehicle.location(at: reportedAt.addingTimeInterval(12.5))
    XCTAssertEqual(quarterPastFirstStep.lat, 47.15, accuracy: 10e-6)
    XCTAssertEqual(quarterPastFirstStep.lng, -122.0, accuracy: 10e-6)

    let onAPoint = vehicle.location(at: reportedAt.addingTimeInterval(10))
    XCTAssertEqual(onAPoint.lat, 47.1, accuracy: 10e-6)
  }

  func testLocationBeforeTrackStarts() {
    let vehicle = self.vehicle(withTrack: true)
    let location = vehicle.location(at: reportedAt.addingTimeInterval(-60))
    XCTAssertEqual(location.lat, 47.0, accuracy: 10e-6)
  }

  func testLocationPastTrackEnd() {
    let vehicle = self.vehicle(withTrack: true)

    let atEnd = vehicle.location(at: reportedAt.addingTimeInterval(20))
    XCTAssertEqual(atEnd.lat, 47.3, accuracy: 10e-6)

    let pastEnd = vehicle.location(at: reportedAt.addingTimeInterval(600))
    XCTAssertEqual(pastEnd.lat, 47.3, accuracy: 10e-6)
  }

  func testLocationWithoutTrack() {
    let vehicle = self.vehicle(withTrack: false)
    let location = vehicle.location(at: reportedAt.addingTimeInterval(600))
    XCTAssertEqual(location.lat, 47.5, accuracy: 10e-6)
    XCTAssertEqual(location.lng, -122.5, accuracy: 10e-6)
  }

  func testIsEstimated() {
    let tracked = self.vehicle(withTrack: true)
    XCTAssertFalse(tracked.isEstimated(at: reportedAt.addingTimeInterval(-1)))
    XCTAssertFalse(tracked.isEstimated(at: reportedAt))
    XCTAssertTrue(tracked.isEstimated(at: reportedAt.addingTimeInterval(1)))

    // Without a track the dot never leaves the position the vehicle reported.
    let untracked = self.vehicle(withTrack: false)
    XCTAssertFalse(untracked.isEstimated(at: reportedAt.addingTimeInterval(600)))
  }

  func testFreshnessFormatted() {
    let untracked = self.vehicle(withTrack: false)
    XCTAssertEqual(
      untracked.freshnessFormatted(at: reportedAt.addingTimeInterval(40)),
      "Location as of 40s ago")

    let tracked = self.vehicle(withTrack: true)
    XCTAssertEqual(
      tracked.freshnessFormatted(at: reportedAt.addingTimeInterval(120)),
      "Estimated · confirmed 2m ago")
  }

  func testDecoding() throws {
    let json = """
      {
        "vehicles": [
          {
            "id": "pattern-1/vehicle-1",
            "patternCode": "pattern-1",
            "route": { "shortName": "5", "longName": null, "color": "FDB71A" },
            "vehicleMode": "BUS",
            "headsign": "Shoreline Greenwood",
            "vehicleId": "f-c23-metrokingcounty:8293",
            "label": "8293",
            "position": [-122.3290329, 47.5998993],
            "lastUpdated": "2026-09-17T18:55:42-07:00",
            "track": {
              "stepSeconds": 5,
              "points": [[-122.329054, 47.599904], [-122.328981, 47.600083]]
            }
          }
        ],
        "serverTime": "2026-09-18T02:00:00Z"
      }
      """
    let response = try JSONDecoder.travelmux.decode(
      VehiclePositionsResponse.self, from: Data(json.utf8))

    XCTAssertEqual(response.vehicles.count, 1)
    let vehicle = response.vehicles[0]
    XCTAssertEqual(vehicle.label, "8293")
    XCTAssertEqual(vehicle.vehicleMode, .bus)
    XCTAssertEqual(vehicle.routeName, "5")
    XCTAssertEqual(vehicle.labelFormatted, "Vehicle 8293")

    let track = try XCTUnwrap(vehicle.track)
    XCTAssertEqual(track.stepSeconds, 5)
    XCTAssertEqual(response.serverTime, Date(timeIntervalSince1970: 1_789_696_800))
    XCTAssertNil(response.unknownPatterns)
    XCTAssertEqual(track.points[0].lat, 47.599904, accuracy: 10e-7)
    XCTAssertEqual(track.points[0].lng, -122.329054, accuracy: 10e-7)
    XCTAssertEqual(vehicle.reportedLocation.lat, 47.5998993, accuracy: 10e-7)
    XCTAssertEqual(vehicle.reportedLocation.lng, -122.3290329, accuracy: 10e-7)
  }

  /// travelmux only sends a track it can walk, so a shorter one is a contract it broke.
  func testDecodingRefusesATrackTooShortToWalk() {
    let json = """
      {
        "stepSeconds": 5,
        "points": [[-122.329054, 47.599904]]
      }
      """
    XCTAssertThrowsError(
      try JSONDecoder.travelmux.decode(VehicleTrack.self, from: Data(json.utf8)))
  }

  func testDecodingUnknownPatterns() throws {
    let json = """
      {
        "vehicles": [],
        "unknownPatterns": ["f-c23-metrokingcounty:999999:0:01"],
        "serverTime": "2026-09-18T02:00:00Z"
      }
      """
    let response = try JSONDecoder.travelmux.decode(
      VehiclePositionsResponse.self, from: Data(json.utf8))
    XCTAssertEqual(response.unknownPatterns, ["f-c23-metrokingcounty:999999:0:01"])
  }

  func testUnknownVehicleMode() throws {
    let mode = try JSONDecoder.travelmux.decode(
      TransitVehicleMode.self, from: Data("\"AIRPLANE\"".utf8))
    XCTAssertEqual(mode, .other("AIRPLANE"))
    XCTAssertEqual(mode.emoji, "🚍")
  }
}
