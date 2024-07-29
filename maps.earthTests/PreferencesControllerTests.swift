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
    let expectation = XCTestExpectation(description: "Open a file asynchronously.")
    Task { @MainActor in
      let preferencesController = PreferencesController(
        fromStorage: StorageController.InMemoryForTesting())
      XCTAssertEqual(preferencesController.preferences.recentSearches, [])
      await preferencesController.addSearch(text: "coffee")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["coffee"])
      await preferencesController.addSearch(text: "books")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["books", "coffee"])
      await preferencesController.addSearch(text: "coffee")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["coffee", "books"])
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 10)
  }

  func testCaseInsensitive() async {
    let expectation = XCTestExpectation(description: "Open a file asynchronously.")
    Task { @MainActor in
      let preferencesController = PreferencesController(
        fromStorage: StorageController.InMemoryForTesting())
      XCTAssertEqual(preferencesController.preferences.recentSearches, [])
      await preferencesController.addSearch(text: "coffee")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["coffee"])
      await preferencesController.addSearch(text: "Coffee")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["Coffee"])
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 10)
  }

  func testOnly10() async {
    let expectation = XCTestExpectation(description: "Open a file asynchronously.")
    Task { @MainActor in
      let preferencesController = PreferencesController(
        fromStorage: StorageController.InMemoryForTesting())
      await preferencesController.addSearch(text: "one")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["one"])
      await preferencesController.addSearch(text: "two")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["two", "one"])
      await preferencesController.addSearch(text: "three")
      await preferencesController.addSearch(text: "four")
      await preferencesController.addSearch(text: "five")
      await preferencesController.addSearch(text: "six")
      await preferencesController.addSearch(text: "seven")
      await preferencesController.addSearch(text: "eight")
      await preferencesController.addSearch(text: "nine")
      await preferencesController.addSearch(text: "ten")
      XCTAssertEqual(
        preferencesController.preferences.recentSearches,
        ["ten", "nine", "eight", "seven", "six", "five", "four", "three", "two", "one"])
      await preferencesController.addSearch(text: "eleven")
      XCTAssertEqual(
        preferencesController.preferences.recentSearches,
        ["eleven", "ten", "nine", "eight", "seven", "six", "five", "four", "three", "two"])
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 10)
  }
}
