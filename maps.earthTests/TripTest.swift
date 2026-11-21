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
    let geometry = trip.legs[0].geometry.coordinates

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
    XCTAssertEqual(trip.distanceMeters, 6965.917, accuracy: 10e-3)
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

  func testRoutePreferences() {
    XCTAssertEqual(FixtureData.bikeTrips[0].routePreferences, [.quieter, .faster])
    XCTAssertEqual(FixtureData.walkTrips[0].routePreferences, [])
  }

  func testWalkManeuvers() {
    let trip = FixtureData.walkTrips[0]
    XCTAssertEqual(trip.duration, 5646.0, accuracy: 10e-3)
    XCTAssertEqual(trip.distanceMeters, 6903.377, accuracy: 10e-3)

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

  func testTransitLegs() {
    let trip = FixtureData.transitTrips[0]
    let leg = try! XCTUnwrap(trip.firstTransitLeg)
    let transitLeg = try! XCTUnwrap(leg.transitLeg)

    XCTAssertEqual(transitLeg.vehicleMode, .bus)
    XCTAssertEqual(transitLeg.routeSummaryName, "C Line")
    XCTAssertEqual(trip.patternCodes, [transitLeg.patternCode])
  }

  func testRepeatDeparturesAreOneGroup() {
    let trips = FixtureData.transitTrips
    XCTAssertEqual(trips.count, 5)

    let groups = TripGroup.group(trips)
    XCTAssertEqual(groups.count, 1)
    XCTAssertEqual(groups[0].trips, trips.sorted { $0.departureTime < $1.departureTime })
    XCTAssertEqual(Self.rideLabels(groups[0]), [["C Line"]])
  }

  func testLinesServingTheSameStopsAreOneGroup() {
    let cLine = FixtureData.transitTrips[0]
    let hLine = Self.trip(cLine) { transitLeg, _ in transitLeg.route?.shortName = "H Line" }

    let groups = TripGroup.group([cLine, hLine])
    XCTAssertEqual(groups.count, 1)
    XCTAssertEqual(Self.rideLabels(groups[0]), [["C Line", "H Line"]])
  }

  func testTripsTravelmuxKeysAlikeAreOneGroup() {
    let original = FixtureData.transitTrips[0]
    func keyed(_ key: String) -> Trip {
      var itinerary = original.raw
      itinerary.tripKey = key
      return Trip(itinerary: itinerary, from: original.from, to: original.to)
    }
    XCTAssertEqual(TripGroup.group([keyed("a"), keyed("a")]).count, 1)
    XCTAssertEqual(TripGroup.group([keyed("a"), keyed("b")]).count, 2)
  }

  func testOtherModesAreNeverGrouped() {
    let trips = FixtureData.driveTrips
    XCTAssertEqual(TripGroup.group(trips).count, trips.count)
  }

  func testMergedRoutesAreBadgedInNameOrder() {
    let cLine = FixtureData.transitTrips[0]
    let line2 = Self.trip(cLine) { transitLeg, _ in transitLeg.route?.shortName = "2 Line" }
    let line10 = Self.trip(cLine) { transitLeg, _ in transitLeg.route?.shortName = "10" }
    let group = TripGroup(trips: [line10, cLine, line2])
    XCTAssertEqual(Self.rideLabels(group), [["2 Line", "10", "C Line"]])
  }

  func testNextDeparture() {
    let group = TripGroup.group(FixtureData.transitTrips)[0]
    let first = group.trips[0]
    let second = group.trips[1]
    XCTAssertEqual(group.nextDeparture(at: first.departureTime), first)
    XCTAssertEqual(group.nextDeparture(at: first.departureTime + 1), second)
    XCTAssertEqual(group.nextDeparture(at: .distantFuture), group.trips.last)
  }

  func testShortWalksAreLeftOutOfTheList() {
    let group = TripGroup.group(FixtureData.transitTrips)[0]
    let listed = group.listedLegs.map(\.legIdx)
    for (legIdx, badge) in group.legBadges.enumerated() {
      guard case .selfPowered(_, let minutes) = badge else {
        XCTAssert(listed.contains(legIdx), "rides are always listed")
        continue
      }
      let atEnd = legIdx == 0 || legIdx == group.legBadges.count - 1
      XCTAssertEqual(listed.contains(legIdx), minutes > (atEnd ? 2 : 1))
    }
  }

  func testRouteBadgeColors() {
    let agency = RouteBadge(
      label: "B", route: TransitRoute(color: "EB131B", textColor: "FFFFFF"))
    XCTAssertEqual(agency.color, RGBColor(rgb: 0xEB131B))
    XCTAssertEqual(agency.textColor, .white)

    let uncolored = RouteBadge(label: "40", route: TransitRoute())
    XCTAssertEqual(uncolored.color, .activeRoute)
    XCTAssertEqual(uncolored.textColor, .black)
  }

  func testShortDuration() {
    let now = Date(timeIntervalSince1970: 0)
    XCTAssertEqual(shortDuration(from: now, to: now + 40), "40 sec")
    XCTAssertEqual(shortDuration(from: now, to: now + 180), "3 min")
  }

  func testDeparturesFormatted() {
    let now = Date(timeIntervalSince1970: 0)
    XCTAssertEqual(departuresFormatted([now + 180, now + 720], now: now), "3 & 12 min")
    XCTAssertEqual(departuresFormatted([now + 180], now: now), "3 min")
    XCTAssertEqual(departuresFormatted([now + 40, now + 540], now: now), "40 sec & 9 min")
  }

  /// The route labels of each ride's pill.
  private static func rideLabels(_ group: TripGroup) -> [[String]] {
    group.legBadges.compactMap { badge in
      guard case .ride(_, let routes) = badge else {
        return nil
      }
      return routes.map(\.label)
    }
  }

  /// `trip` with its transit leg changed by `change`.
  private static func trip(
    _ trip: Trip, change: (inout TransitLeg, inout ItineraryLeg) -> Void
  ) -> Trip {
    var itinerary = trip.raw
    itinerary.legs = itinerary.legs.map { leg in
      guard var transitLeg = leg.transitLeg else {
        return leg
      }
      var leg = leg
      change(&transitLeg, &leg)
      leg.modeLeg = .transit(transitLeg)
      return leg
    }
    return Trip(itinerary: itinerary, from: trip.from, to: trip.to)
  }

  func testErrorResponse() {
    let tripError = FixtureData.bikeTripError
    XCTAssertEqual(tripError.errorCode, TripPlanErrorCode(rawValue: 2154))
  }

  /// `YYYY` is the week-based year, which in the last days of December is already next year.
  func testTransitDateIsTheCalendarYear() {
    let date = Calendar.current.date(
      from: DateComponents(year: 2024, month: 12, day: 30, hour: 12))!
    let params = TripPlanNetworkClient.QueryParams(
      from: LngLat(lng: -122.378248, lat: 47.563412),
      to: LngLat(lng: -122.331856, lat: 47.599091),
      modes: [.transit],
      measurementSystem: .imperial,
      tripDate: .departAt(date))

    let dateTime = params.asQueryItems.first { $0.name == "dateTime" }?.value
    XCTAssertEqual(dateTime, "2024-12-30T12:00")
  }
}
