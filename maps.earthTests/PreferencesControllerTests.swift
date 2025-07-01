//
//  PreferencesControllerTests.swift
//  maps.earthTests
//
//  Created by Michael Kirk on 4/16/24.
//

import Foundation
import XCTest

@testable import maps_earth

final class PreferencesControllerTests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func noRepeats() async {
    let preferencesController = PreferencesController(
      fromStorage: StorageController.InMemoryForTesting())

    var recentSearches = try! await preferencesController.load().recentSearches
    XCTAssertEqual(recentSearches, [])

    recentSearches = await preferencesController.addSearch(text: "coffee")
    XCTAssertEqual(recentSearches, ["coffee"])

    recentSearches = await preferencesController.addSearch(text: "books")
    XCTAssertEqual(recentSearches, ["books", "coffee"])

    recentSearches = await preferencesController.addSearch(text: "coffee")
    XCTAssertEqual(recentSearches, ["coffee", "books"])
  }

  func testCaseInsensitive() async {
    let preferencesController = PreferencesController(
      fromStorage: StorageController.InMemoryForTesting())

    var recentSearches = try! await preferencesController.load().recentSearches
    XCTAssertEqual(recentSearches, [])
    recentSearches = await preferencesController.addSearch(text: "coffee")
    XCTAssertEqual(recentSearches, ["coffee"])
    recentSearches = await preferencesController.addSearch(text: "Coffee")
    XCTAssertEqual(recentSearches, ["Coffee"])
  }

  func testOnly10() async {
    let preferencesController = PreferencesController(
      fromStorage: StorageController.InMemoryForTesting())

    var recentSearches = await preferencesController.addSearch(text: "one")
    XCTAssertEqual(recentSearches, ["one"])
    recentSearches = await preferencesController.addSearch(text: "two")
    XCTAssertEqual(recentSearches, ["two", "one"])
    recentSearches = await preferencesController.addSearch(text: "three")
    recentSearches = await preferencesController.addSearch(text: "four")
    recentSearches = await preferencesController.addSearch(text: "five")
    recentSearches = await preferencesController.addSearch(text: "six")
    recentSearches = await preferencesController.addSearch(text: "seven")
    recentSearches = await preferencesController.addSearch(text: "eight")
    recentSearches = await preferencesController.addSearch(text: "nine")
    recentSearches = await preferencesController.addSearch(text: "ten")
    XCTAssertEqual(
      recentSearches,
      ["ten", "nine", "eight", "seven", "six", "five", "four", "three", "two", "one"])
    recentSearches = await preferencesController.addSearch(text: "eleven")
    XCTAssertEqual(
      recentSearches,
      ["eleven", "ten", "nine", "eight", "seven", "six", "five", "four", "three", "two"])
  }
}
