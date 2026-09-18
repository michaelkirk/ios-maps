//
//  VehiclePositionsRequestTest.swift
//  maps.earthTests
//

import XCTest

@testable import maps_earth

final class VehiclePositionsRequestTest: XCTestCase {
  let endpoint = URL(string: "https://maps.earth/travelmux/v7")!
  let from = LngLat(lng: -122.339414, lat: 47.575837)
  let to = LngLat(lng: -122.347234, lat: 47.651048)

  func queryItems(_ url: URL) -> [String: String] {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    return Dictionary(
      uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value ?? "") })
  }

  /// The server measures "nearby" from where the rider boards, so a pattern that names one is
  /// written `<code>@<lat>,<lon>`.
  func testPatternWithBoardingStop() {
    let pattern = PatternRequest(
      code: "f-c23-metrokingcounty:100229:0:01",
      boardingStop: LngLat(lng: -122.328957, lat: 47.5933418))

    XCTAssertEqual(
      pattern.asQueryValue, "f-c23-metrokingcounty:100229:0:01@47.5933418,-122.328957")
  }

  /// Without one the server can't rank, and reports every vehicle on the pattern.
  func testPatternWithoutBoardingStop() {
    let pattern = PatternRequest(code: "f-c23-metrokingcounty:100229:0:01", boardingStop: nil)

    XCTAssertEqual(pattern.asQueryValue, "f-c23-metrokingcounty:100229:0:01")
  }

  func testPatternsAreSeparatedBySemicolons() {
    let url = VehiclePositionsClient.url(
      endpoint: endpoint, from: from, to: to,
      patterns: [
        PatternRequest(code: "1:40:0:01", boardingStop: LngLat(lng: -122.33, lat: 47.6)),
        PatternRequest(code: "1:21:0:01", boardingStop: nil),
      ])

    // A `;` rather than a `,`, because a boarding stop has a comma of its own.
    XCTAssertEqual(queryItems(url)["patterns"], "1:40:0:01@47.6,-122.33;1:21:0:01")
  }

  func testPlaceCoordinatesAreLatThenLon() {
    let url = VehiclePositionsClient.url(
      endpoint: endpoint, from: from, to: to, patterns: [])

    XCTAssertEqual(queryItems(url)["fromPlace"], "47.575837,-122.339414")
    XCTAssertEqual(queryItems(url)["toPlace"], "47.651048,-122.347234")
  }

  func testPathIsAppendedToTheEndpoint() {
    let url = VehiclePositionsClient.url(
      endpoint: endpoint, from: from, to: to, patterns: [])

    XCTAssertEqual(url.path(), "/travelmux/v7/vehicle_positions")
  }

  /// The separators have to survive being put in a URL, since the server splits on them.
  func testSeparatorsSurviveEncoding() {
    let url = VehiclePositionsClient.url(
      endpoint: endpoint, from: from, to: to,
      patterns: [
        PatternRequest(code: "1:40:0:01", boardingStop: LngLat(lng: -122.33, lat: 47.6)),
        PatternRequest(code: "1:21:0:01", boardingStop: LngLat(lng: -122.34, lat: 47.61)),
      ])

    // Whatever percent-encoding the URL uses, what a server reads back has to be what we meant.
    let decoded = queryItems(url)["patterns"]
    XCTAssertEqual(decoded?.components(separatedBy: ";").count, 2)
    XCTAssertEqual(decoded?.components(separatedBy: ";").first, "1:40:0:01@47.6,-122.33")
  }
}
