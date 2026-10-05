import XCTest

@testable import maps_earth

@MainActor
final class TripPlanTest: XCTestCase {
  func testSwapEndpoints() {
    let from = FixtureData.places[.realfine]
    let to = FixtureData.places[.zeitgeist]
    let tripPlan = TripPlan(from: from, to: to, trips: .success(FixtureData.walkTrips))
    XCTAssertNotNil(tripPlan.selectedTrip)

    tripPlan.swapEndpoints()

    XCTAssertEqual(tripPlan.navigateFrom, to)
    XCTAssertEqual(tripPlan.navigateTo, from)
    XCTAssertNil(tripPlan.selectedTrip)
    guard case .success(let trips) = tripPlan.trips else {
      return XCTFail("unexpected trips: \(tripPlan.trips)")
    }
    XCTAssertTrue(trips.isEmpty)
  }
}
