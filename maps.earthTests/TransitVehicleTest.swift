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
  func vehicle(withTrack: Bool, boardingStop: BoardingStop? = nil) -> TransitVehicle {
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
      track: withTrack ? track : nil,
      boardingStop: boardingStop)
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

  /// A vehicle due at the rider's stop `seconds` from `reportedAt`, on the given side of it.
  func arrivingIn(_ seconds: TimeInterval, _ state: (Date) -> BoardingStop) -> TransitVehicle {
    vehicle(withTrack: false, boardingStop: state(reportedAt.addingTimeInterval(seconds)))
  }

  func testBoardingStopRowCountsDownWhileApproaching() throws {
    let vehicle = arrivingIn(180) { .approaching(arrival: $0, stopArrivals: []) }
    let row = try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt))
    XCTAssertEqual(row.text, "Approaching")
    XCTAssertEqual(row.countdown?.value, "3")
    XCTAssertEqual(row.countdown?.unit, "min")
  }

  /// A countdown of seconds is no use to someone who should be looking up the street.
  func testBoardingStopRowSaysWhenAVehicleIsAboutToArrive() throws {
    let vehicle = arrivingIn(20) { .approaching(arrival: $0, stopArrivals: []) }
    let row = try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt))
    XCTAssertEqual(row.text, "Arriving now")
    XCTAssertNil(row.countdown)
  }

  func testBoardingStopRowKeepsTheMinutesPastAnHour() throws {
    let vehicle = arrivingIn(3 * 3600 + 5 * 60) { .approaching(arrival: $0, stopArrivals: []) }
    let row = try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt))
    XCTAssertEqual(row.countdown?.value, "3:05")
    XCTAssertEqual(row.countdown?.unit, "hr")
  }

  func testBoardingStopRowCountsSecondsUnderAMinute() throws {
    let vehicle = arrivingIn(45) { .approaching(arrival: $0, stopArrivals: []) }
    let row = try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt))
    XCTAssertEqual(row.countdown?.value, "45")
    XCTAssertEqual(row.countdown?.unit, "sec")
  }

  /// Nothing left to wait through once it has been and gone.
  func testBoardingStopRowSaysHowLongAgoAVehicleLeft() throws {
    let vehicle = arrivingIn(-120) { .departed(arrival: $0) }
    let row = try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt))
    XCTAssertEqual(row.text, "Left 2m ago")
    XCTAssertNil(row.countdown)
  }

  /// travelmux decides which side of the stop a vehicle is on, so a late one can be past the stop
  /// with an arrival still a few seconds out.
  func testBoardingStopRowDoesNotCountBackwards() throws {
    let vehicle = arrivingIn(5) { .departed(arrival: $0) }
    let row = try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt))
    XCTAssertEqual(row.text, "Left 0s ago")
  }

  func testBoardingStopRowCountsStopsDownAsTheVehicleMoves() throws {
    let vehicle = arrivingIn(180) {
      .approaching(
        arrival: $0,
        stopArrivals: [
          reportedAt.addingTimeInterval(30),
          reportedAt.addingTimeInterval(90),
          reportedAt.addingTimeInterval(180),
        ])
    }

    XCTAssertEqual(try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt)).text, "3 stops away")
    XCTAssertEqual(
      try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt.addingTimeInterval(30))).text,
      "2 stops away")
    XCTAssertEqual(
      try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt.addingTimeInterval(90))).text,
      "Next stop")
    XCTAssertEqual(
      try XCTUnwrap(vehicle.boardingStopRow(at: reportedAt.addingTimeInterval(160))).text,
      "Next stop")
  }

  func testBoardingStopRowOfAVehicleTravelmuxSaidNothingAbout() {
    XCTAssertNil(vehicle(withTrack: false).boardingStopRow(at: reportedAt))
  }

  func testDecodingBoardingStop() throws {
    let json = """
      {
        "state": "approaching",
        "arrival": "2026-09-17T18:55:42-07:00",
        "stopArrivals": [
          "2026-09-17T18:52:42-07:00",
          "2026-09-17T18:54:42-07:00",
          "2026-09-17T18:55:42-07:00"
        ]
      }
      """
    let boardingStop = try JSONDecoder.travelmux.decode(
      BoardingStop.self, from: Data(json.utf8))
    XCTAssertEqual(
      boardingStop,
      .approaching(
        arrival: Date(timeIntervalSince1970: 1_789_696_542),
        stopArrivals: [
          Date(timeIntervalSince1970: 1_789_696_362),
          Date(timeIntervalSince1970: 1_789_696_482),
          Date(timeIntervalSince1970: 1_789_696_542),
        ]))

    let departed = try JSONDecoder.travelmux.decode(
      BoardingStop.self,
      from: Data(#"{"state": "departed", "arrival": "2026-09-17T18:55:42-07:00"}"#.utf8))
    XCTAssertEqual(departed, .departed(arrival: Date(timeIntervalSince1970: 1_789_696_542)))
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
            },
            "boardingStop": {
              "state": "approaching",
              "arrival": "2026-09-17T19:02:42-07:00"
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
    XCTAssertEqual(
      vehicle.boardingStop,
      .approaching(arrival: Date(timeIntervalSince1970: 1_789_696_962), stopArrivals: []))

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

  /// A report from a couple of missed polls ago is still worth drawing; one past the track's end
  /// is not.
  func testExpiry() throws {
    let subject = vehicle(withTrack: true)

    XCTAssertFalse(subject.hasExpired(at: reportedAt.addingTimeInterval(60)))
    XCTAssertFalse(subject.hasExpired(at: reportedAt.addingTimeInterval(180)))
    XCTAssertTrue(subject.hasExpired(at: reportedAt.addingTimeInterval(181)))
  }

  func testUnknownVehicleMode() throws {
    let mode = try JSONDecoder.travelmux.decode(
      TransitVehicleMode.self, from: Data("\"AIRPLANE\"".utf8))
    XCTAssertEqual(mode, .other("AIRPLANE"))
    XCTAssertEqual(mode.emoji, "🚍")
  }
}

final class TrackCorrectionTest: XCTestCase {
  let startedAt = Date(timeIntervalSince1970: 1_700_000_000)

  func testAnUncorrectedDotSitsOnItsTrack() throws {
    let subject = TrackCorrection()

    XCTAssertEqual(subject.apply(to: LngLat(lng: 10, lat: 0), at: startedAt).lng, 10)
  }

  func testADotClosesOnAReplacementTrack() throws {
    let subject = TrackCorrection()
    subject.begin(at: LngLat(lng: 0, lat: 0), startedAt)

    XCTAssertEqual(
      subject.apply(to: LngLat(lng: 10, lat: 0), at: startedAt.addingTimeInterval(0.5)).lng, 5)
    XCTAssertEqual(
      subject.apply(to: LngLat(lng: 20, lat: 0), at: startedAt.addingTimeInterval(1)).lng, 20)
  }

  /// A poll landing mid-correction picks up where the dot is, so corrections follow one another
  /// rather than fighting.
  func testAPollArrivingMidCorrection() throws {
    let subject = TrackCorrection()
    subject.begin(at: LngLat(lng: 0, lat: 0), startedAt)
    let midway = startedAt.addingTimeInterval(0.5)
    let drawn = subject.apply(to: LngLat(lng: 10, lat: 0), at: midway)
    subject.begin(at: drawn, midway)

    XCTAssertEqual(subject.apply(to: LngLat(lng: 20, lat: 0), at: midway).lng, 5)
  }
}
