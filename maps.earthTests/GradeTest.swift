//
//  GradeTest.swift
//  maps.earthTests
//

import CoreLocation
import Turf
import XCTest

@testable import maps_earth

final class GradeTest: XCTestCase {
  func section(_ startMeters: Double, _ endMeters: Double, _ grade: Double) -> SteepSection {
    SteepSection(
      startMeters: startMeters, endMeters: endMeters, averageGrade: grade, maxGrade: grade,
      streetName: nil, geometry: LineString([]), annotated: false)
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
    XCTAssertEqual(elevation.steepSections.count, 5)
    XCTAssertEqual(elevation.annotatedClimbs.map(\.percent), [7, 9])
    XCTAssertEqual(elevation.annotatedClimbs[1].streetName, "East Thomas Street")
    XCTAssertNil(elevation.steepSections[0].streetName)
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
      geometry: LineString([
        CLLocationCoordinate2D(latitude: 0, longitude: 0),
        CLLocationCoordinate2D(latitude: 0, longitude: 0.009),
      ]),
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
    XCTAssertEqual(leg.selectedGeometry.coordinates.count, 1)
  }

  func testAWalkToTransitLeavesOutItsSteepStretches() {
    let leg = walkLeg(tripMode: .transit)
    XCTAssertTrue(leg.isDotted)
    let pieces = leg.selectedGeometry.coordinates
    XCTAssertEqual(pieces.count, 2)
    // the leg runs about 1000 m east
    let metersPerDegree = 1000 / 0.009
    XCTAssertEqual(pieces[0].first!.longitude, 0)
    XCTAssertEqual(pieces[0].last!.longitude * metersPerDegree, 400, accuracy: 5)
    XCTAssertEqual(pieces[1].first!.longitude * metersPerDegree, 600, accuracy: 5)
    XCTAssertEqual(pieces[1].last!.longitude, 0.009)
  }
}
