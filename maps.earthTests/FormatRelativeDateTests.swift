//
//  FormatRelativeDateTests.swift
//  maps.earthTests
//
//  Created by Michael Kirk on 4/24/24.
//

import XCTest

@testable import maps_earth

let now = Date(timeIntervalSince1970: 1_713_987_000)
final class FormatRelativeDateTests: XCTestCase {
  func testNow() throws {
    XCTAssertEqual("12:30", formatRelativeDate(now, relativeTo: now))
  }

  func testLaterToday() throws {
    XCTAssertEqual("12:35", formatRelativeDate(now.addingTimeInterval(300), relativeTo: now))
  }

  func testEarlierToday() throws {
    XCTAssertEqual("12:25", formatRelativeDate(now.addingTimeInterval(-300), relativeTo: now))
  }

  func testTomorrow() throws {
    let date = now.addingTimeInterval(60 * 60 * 20)
    // This test is brittle due to Locale (e.g. 12 vs. 24 hour clock)
    XCTAssertEqual("08:30 Tomorrow", formatRelativeDate(date, relativeTo: now))
  }

  func testLaterThisWeek() throws {
    XCTAssertEqual(
      "12:30 Monday", formatRelativeDate(now.addingTimeInterval(60 * 60 * 24 * 5), relativeTo: now))
  }

  func testFarFuture() throws {
    XCTAssertEqual(
      "12:30 May 4", formatRelativeDate(now.addingTimeInterval(60 * 60 * 24 * 10), relativeTo: now))
  }
}
