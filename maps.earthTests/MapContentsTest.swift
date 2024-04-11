//
//  MapContentsTest.swift
//  maps.earthTests
//
//  Created by Michael Kirk on 4/11/24.
//

import XCTest

@testable import maps_earth

let dubsea = PlaceMarker(place: FixtureData.places[.dubsea].intoMarkerLocation, style: .pin)
let zeitgeist = PlaceMarker(place: FixtureData.places[.zeitgeist].intoMarkerLocation, style: .pin)

final class MapContentsTest: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testAddingPins() throws {
    do {
      let oldContents = MapContents.empty
      let newContents = MapContents.pins(selected: nil, unselected: [dubsea])
      let diff = oldContents.diff(newContents: newContents)
      XCTAssertEqual(diff.adds.count, 1)
      XCTAssertEqual(diff.removes.count, 0)
      XCTAssertEqual(diff.adds[0] as! PlaceMarker, dubsea)
      XCTAssert(diff.removes.isEmpty)
    }
    do {
      let oldContents = MapContents.pins(selected: nil, unselected: [dubsea])
      let newContents = MapContents.pins(selected: nil, unselected: [dubsea, zeitgeist])
      let diff = oldContents.diff(newContents: newContents)
      XCTAssertEqual(diff.adds.count, 1)
      XCTAssertEqual(diff.removes.count, 0)
      XCTAssertEqual(diff.adds[0] as! PlaceMarker, zeitgeist)
      XCTAssert(diff.removes.isEmpty)
    }
  }

  func removingPins() throws {
    do {
      let oldContents = MapContents.pins(selected: nil, unselected: [dubsea, zeitgeist])
      let newContents = MapContents.pins(selected: nil, unselected: [dubsea])
      let diff = oldContents.diff(newContents: newContents)
      XCTAssertEqual(diff.adds.count, 0)
      XCTAssertEqual(diff.removes.count, 1)
      XCTAssertEqual(diff.removes[0] as! PlaceMarker, zeitgeist)
      XCTAssert(diff.removes.isEmpty)
    }
    do {
      let oldContents = MapContents.pins(selected: nil, unselected: [dubsea, zeitgeist])
      let newContents = MapContents.empty
      let diff = oldContents.diff(newContents: newContents)
      XCTAssertEqual(diff.adds.count, 0)
      XCTAssertEqual(diff.removes.count, 2)
      XCTAssertEqual(diff.removes[0] as! PlaceMarker, dubsea)
      XCTAssertEqual(diff.removes[0] as! PlaceMarker, zeitgeist)
      XCTAssert(diff.removes.isEmpty)
    }
  }
}