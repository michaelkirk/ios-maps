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
    // Looking across campus at Suzzallo Library.
    show(viewport: "17/47.6563/-122.3093/330/60")
    try snapshot("01-home")

    XCUIDevice.shared.system.open(URL(string: "mapsearth:///place/\(Self.spaceNeedle)")!)
    XCTAssert(app.buttons["Directions"].waitForExistence(timeout: 30))
    // Looking past the Space Needle toward downtown.
    show(viewport: "16.3/47.6196/-122.3488/160/60")
    try snapshot("02-place-details")

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
    // The whole trip, with room above the train for its callout.
    show(viewport: "10.4/47.6379/-122.327")
    train.tap()
    try snapshot("03-transit-bike-directions")

    app.buttons["Steps"].firstMatch.tap()
    XCTAssert(app.staticTexts["Steps"].waitForExistence(timeout: 10))
    try snapshot("04-transit-bike-steps")

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
    // Let the simulated ride get underway.
    sleep(10)
    app.pinch(withScale: 2, velocity: 1)
    // Let the 3D buildings load in.
    sleep(5)
    try snapshot("05-navigation")
  }

  /// Moves the map to a `#map=zoom/lat/lng[/bearing[/pitch]]` viewport, leaving the sheet as is.
  func show(viewport: String) {
    // Let any zoom to the sheet's content finish first, so it doesn't override the viewport.
    sleep(2)
    XCUIDevice.shared.system.open(URL(string: "mapsearth:///#map=\(viewport)")!)
    sleep(1)
  }

  func snapshot(_ name: String) throws {
    // Let map tiles finish loading and animations settle.
    sleep(4)
    let png = XCUIScreen.main.screenshot().pngRepresentation
    try png.write(to: outputDir.appending(path: "\(name).png"))
  }
}
