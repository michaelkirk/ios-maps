//
//  FormatRelativeDateTests.swift
//  maps.earthTests
//
//  Created by Michael Kirk on 4/24/24.
//

import XCTest

@testable import maps_earth

let now = Date(timeIntervalSince1970: 1_713_987_000)
// Disabled for now for CI. To re-enable we need to
// 1. Set the simulator timezone TZ=America/Los_Angeles
// 2. Ensure the locale is en-US (maybe that's default though?) - we could add a DI locale = Locale.current to the method
// 3. Set the clock to 24 hour to match my own clock preferences. I haven't figured out how to do this.
let enabled = false
final class FormatRelativeDateTests: XCTestCase {
  func testNow() throws {
    guard enabled else { return }
    XCTAssertEqual("12:30", formatRelativeDate(now, relativeTo: now))
  }

  func testLaterToday() throws {
    guard enabled else { return }
    XCTAssertEqual("12:35", formatRelativeDate(now.addingTimeInterval(300), relativeTo: now))
  }

  func testEarlierToday() throws {
    guard enabled else { return }
    XCTAssertEqual("12:25", formatRelativeDate(now.addingTimeInterval(-300), relativeTo: now))
  }

  func testTomorrow() throws {
    guard enabled else { return }
    let date = now.addingTimeInterval(60 * 60 * 20)
    // This test is brittle due to Locale (e.g. 12 vs. 24 hour clock)
    XCTAssertEqual("08:30 Tomorrow", formatRelativeDate(date, relativeTo: now))
  }

  func testLaterThisWeek() throws {
    guard enabled else { return }
    XCTAssertEqual(
      "12:30 Monday", formatRelativeDate(now.addingTimeInterval(60 * 60 * 24 * 5), relativeTo: now))
  }

  func testFarFuture() throws {
    guard enabled else { return }
    XCTAssertEqual(
      "12:30 May 4", formatRelativeDate(now.addingTimeInterval(60 * 60 * 24 * 10), relativeTo: now))
  }
}
