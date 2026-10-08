//
//  GradeTest.swift
//  maps.earthTests
//

import CoreLocation
import XCTest

@testable import maps_earth

final class GradeTest: XCTestCase {
  func section(_ startMeters: Double, _ endMeters: Double, _ grade: Double) -> SteepSection {
    SteepSection(
      startMeters: startMeters, endMeters: endMeters, averageGrade: grade, maxGrade: grade,
      streetName: nil, geometry: "")
  }

  func elevation(_ sections: [SteepSection]) -> LegElevation {
    LegElevation(
      profile: [
        .init(distance: 100, elevation: 0), .init(distance: 500, elevation: 10),
      ], totalClimbMeters: 10, totalFallMeters: 0, steepSections: sections)
  }

  func testDecodesTheLegsElevation() throws {
    let elevation = try XCTUnwrap(FixtureData.bikeGradeTrips[0].elevation)
    XCTAssertFalse(elevation.profile.isEmpty)
    XCTAssertEqual(elevation.steepSections.count, 3)
    XCTAssertEqual(elevation.steepSections[0].percent, 12)
    XCTAssertEqual(elevation.steepSections[0].streetName, "East Spring Street")
  }

  func testDropsSteepSectionsWithNothingToDraw() throws {
    let json = """
      {
        "profile": [[0, 10], [100, 20]],
        "totalClimbMeters": 10,
        "totalFallMeters": 0,
        "steepSections": [
          {"startMeters": 0, "endMeters": 50, "averageGrade": 0.1, "maxGrade": 0.1,
           "geometry": "_ibE_ibE_seK_seK"},
          {"startMeters": 50, "endMeters": 100, "averageGrade": 0.1, "maxGrade": 0.1,
           "geometry": ""}
        ]
      }
      """
    let elevation = try JSONDecoder().decode(LegElevation.self, from: Data(json.utf8))
    XCTAssertEqual(elevation.steepSections.map(\.startMeters), [0])
  }

  func testAnnotatesTheThreeSteepestClimbs() {
    let sections = [
      section(0, 100, 0.06), section(200, 300, 0.1), section(400, 500, -0.2),
      section(600, 700, 0.07), section(800, 900, 0.14),
    ]
    XCTAssertEqual(
      elevation(sections).annotatedClimbs, [sections[4], sections[1], sections[3]])
  }

  func testSkipsAClimbWithin100mOfASteeperOne() {
    let sections = [section(0, 100, 0.14), section(150, 250, 0.12), section(300, 400, 0.06)]
    XCTAssertEqual(elevation(sections).annotatedClimbs, [sections[0], sections[2]])
  }

  func testShadesClimbsAndDescentsBySteepness() {
    XCTAssertEqual(GradeShade(grade: 0.06), .moderateClimb)
    XCTAssertEqual(GradeShade(grade: 0.14), .verySteepClimb)
    XCTAssertEqual(GradeShade(grade: -0.06), .moderateDescent)
    XCTAssertEqual(GradeShade(grade: -0.1), .steepDescent)
  }

  func testDescribesTheGrade() {
    XCTAssertEqual(section(0, 100, 0.06).gradeDescription, "6% moderate grade")
    XCTAssertEqual(section(0, 100, 0.14).gradeDescription, "14% very steep grade")
  }

  func testMidpointFractionMeasuresFromWhereTheProfileStarts() {
    let climb = section(200, 300, 0.1)
    XCTAssertEqual(elevation([climb]).midpointFraction(of: climb), 0.375, accuracy: 1e-9)
  }

  /// About 1000 m east along the equator, steep from 400 m to 600 m.
  func walkLeg(tripMode: TravelMode) -> TripLeg {
    let place = TripPlace(location: LngLat(lng: 0, lat: 0), name: nil)
    return TripLeg(
      geometry: [
        CLLocationCoordinate2D(latitude: 0, longitude: 0),
        CLLocationCoordinate2D(latitude: 0, longitude: 0.009),
      ],
      fromPlace: place, toPlace: place, startTime: .now, endTime: .now, mode: .walk,
      modeLeg: .nonTransit(
        NonTransitLeg(
          maneuvers: [], substantialStreetNames: [],
          elevation: elevation([section(400, 600, 0.1)]))),
      tripMode: tripMode)
  }

  func testFractionNearestUndoesPointAlong() {
    let leg = walkLeg(tripMode: .walk)
    for fraction in [0, 0.3, 0.95, 1] {
      let point = leg.pointAlong(fraction: fraction)
      XCTAssertEqual(leg.fractionNearest(point), fraction, accuracy: 1e-5)
    }
  }

  func testFractionNearestSnapsAPointOffTheLineOntoIt() {
    let leg = walkLeg(tripMode: .walk)
    let offLine = CLLocationCoordinate2D(latitude: -0.0005, longitude: 0.0045)
    XCTAssertEqual(leg.fractionNearest(offLine), 0.5, accuracy: 1e-3)
  }

  func testAWalkOfItsOwnIsDrawnWhole() {
    let leg = walkLeg(tripMode: .walk)
    XCTAssertFalse(leg.isDotted)
    XCTAssertEqual(leg.selectedGeometry.count, 1)
  }

  func testAWalkToTransitLeavesOutItsSteepStretches() {
    let leg = walkLeg(tripMode: .transit)
    XCTAssertTrue(leg.isDotted)
    let pieces = leg.selectedGeometry
    XCTAssertEqual(pieces.count, 2)
    // the leg runs about 1000 m east
    let metersPerDegree = 1000 / 0.009
    XCTAssertEqual(pieces[0].first!.longitude, 0)
    XCTAssertEqual(pieces[0].last!.longitude * metersPerDegree, 400, accuracy: 5)
    XCTAssertEqual(pieces[1].first!.longitude * metersPerDegree, 600, accuracy: 5)
    XCTAssertEqual(pieces[1].last!.longitude, 0.009)
  }
}
