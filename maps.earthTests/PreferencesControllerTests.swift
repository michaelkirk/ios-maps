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
      try! await preferencesController.addSearch(text: "coffee")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["coffee"])
      try! await preferencesController.addSearch(text: "books")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["books", "coffee"])
      try! await preferencesController.addSearch(text: "coffee")
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
      try! await preferencesController.addSearch(text: "coffee")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["coffee"])
      try! await preferencesController.addSearch(text: "Coffee")
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
      try! await preferencesController.addSearch(text: "one")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["one"])
      try! await preferencesController.addSearch(text: "two")
      XCTAssertEqual(preferencesController.preferences.recentSearches, ["two", "one"])
      try! await preferencesController.addSearch(text: "three")
      try! await preferencesController.addSearch(text: "four")
      try! await preferencesController.addSearch(text: "five")
      try! await preferencesController.addSearch(text: "six")
      try! await preferencesController.addSearch(text: "seven")
      try! await preferencesController.addSearch(text: "eight")
      try! await preferencesController.addSearch(text: "nine")
      try! await preferencesController.addSearch(text: "ten")
      XCTAssertEqual(
        preferencesController.preferences.recentSearches,
        ["ten", "nine", "eight", "seven", "six", "five", "four", "three", "two", "one"])
      try! await preferencesController.addSearch(text: "eleven")
      XCTAssertEqual(
        preferencesController.preferences.recentSearches,
        ["eleven", "ten", "nine", "eight", "seven", "six", "five", "four", "three", "two"])
      expectation.fulfill()
    }
    await fulfillment(of: [expectation], timeout: 10)
  }
}
