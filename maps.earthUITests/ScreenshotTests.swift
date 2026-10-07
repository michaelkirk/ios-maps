//
//  ScreenshotTests.swift
//  maps.earthUITests
//

import XCTest

/// Drives the app through each App Store screenshot. Run via bin/capture-screenshots.
final class ScreenshotTests: XCTestCase {
  static let spaceNeedle = "openstreetmap%3Avenue%3Away%2F12903132"
  static let pikePlaceMarket = "openstreetmap%3Avenue%3Away%2F363400641"
  static let suzzalloLibrary = "openstreetmap%3Avenue%3Arelation%2F2955450"

  let app = XCUIApplication()
  var outputDir: URL!

  override func setUpWithError() throws {
    continueAfterFailure = false
    // xcodebuild hands TEST_RUNNER_-prefixed variables to the runner, minus the prefix.
    let path = try XCTUnwrap(
      ProcessInfo.processInfo.environment["SCREENSHOT_DIR"],
      "set TEST_RUNNER_SCREENSHOT_DIR")
    outputDir = URL(filePath: path)
  }

  func testCaptureScreenshots() throws {
    app.launchArguments += ["-screenshotTrain", "YES"]
    app.launch()
    XCTAssert(app.staticTexts["Favorites"].waitForExistence(timeout: 30))
    app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'location'")).firstMatch.tap()
    sleep(4)
    // Locating centers the user above the sheet at a regional zoom; zoom into the neighborhood.
    let userLocation = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.281))
    for _ in 0..<8 {
      userLocation.doubleTap()
      sleep(1)
    }
    try snapshot("05-home")

    XCUIDevice.shared.system.open(URL(string: "mapsearth:///place/\(Self.spaceNeedle)")!)
    XCTAssert(app.buttons["Directions"].waitForExistence(timeout: 30))
    try snapshot("04-place-details")

    XCUIDevice.shared.system.open(
      URL(string: "mapsearth:///directions/transit/\(Self.spaceNeedle)/\(Self.suzzalloLibrary)")!)
    let bringABike = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Bring a bike'"))
      .firstMatch
    XCTAssert(bringABike.waitForExistence(timeout: 30))
    bringABike.tap()
    let bikeTrip = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '🚲'"))
      .firstMatch
    XCTAssert(bikeTrip.waitForExistence(timeout: 30))
    // Vehicle markers are buttons labeled with their route, like "2 Line".
    let train = app.buttons.matching(NSPredicate(format: "label ENDSWITH ' Line'")).firstMatch
    XCTAssert(train.waitForExistence(timeout: 30))
    // Move the train clear of the status bar and the map buttons, so its callout isn't covered.
    let target = CGPoint(x: app.frame.width * 0.62, y: app.frame.height * 0.2)
    let offset = CGVector(dx: target.x - train.frame.midX, dy: target.y - train.frame.midY)
    let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.2))
    dragStart.press(
      forDuration: 0.5,
      thenDragTo: dragStart.withOffset(offset),
      withVelocity: .slow,
      // Holding before release keeps the map from flinging on past the drag.
      thenHoldForDuration: 0.5)
    sleep(1)
    train.tap()
    try snapshot("01-transit-bike-directions")

    app.buttons["Steps"].firstMatch.tap()
    XCTAssert(app.staticTexts["Steps"].waitForExistence(timeout: 10))
    try snapshot("02-transit-bike-steps")

    XCUIDevice.shared.system.open(
      URL(
        string: "mapsearth:///directions/bicycle/\(Self.pikePlaceMarket)/\(Self.spaceNeedle)")!)
    let go = app.buttons["GO"]
    XCTAssert(go.waitForExistence(timeout: 30))
    // A tap while the trip list is still settling gets lost.
    sleep(4)
    go.tap()
    // Navigation covers the trip list rather than replacing it.
    let covered = expectation(for: NSPredicate(format: "isHittable == false"), evaluatedWith: go)
    wait(for: [covered], timeout: 10)
    // Let the simulated ride get underway, and the 3D buildings load in.
    sleep(15)
    try snapshot("03-navigation")
  }

  func snapshot(_ name: String) throws {
    // Let map tiles finish loading and animations settle.
    sleep(4)
    let png = XCUIScreen.main.screenshot().pngRepresentation
    try png.write(to: outputDir.appending(path: "\(name).png"))
  }
}
