//
//  VehiclePositionsRequestTest.swift
//  maps.earthTests
//

import XCTest

@testable import maps_earth

final class VehiclePositionsRequestTest: XCTestCase {
  let endpoint = URL(string: "https://maps.earth/travelmux/v8")!
  let from = LngLat(lng: -122.339414, lat: 47.575837)
  let to = LngLat(lng: -122.347234, lat: 47.651048)

  func body(_ request: URLRequest) throws -> [String: Any] {
    let data = try XCTUnwrap(request.httpBody)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  func patterns(_ body: [String: Any]) throws -> [[String: Any]] {
    try XCTUnwrap(body["patterns"] as? [[String: Any]])
  }

  /// Longitude first. A swapped pair is still a valid point to the server, somewhere in the
  /// Indian Ocean, so nothing downstream would report the mistake.
  func testPlaceCoordinatesAreLonThenLat() throws {
    let request = try VehiclePositionsClient.urlRequest(
      endpoint: endpoint, from: from, to: to, patterns: [])

    let body = try self.body(request)
    XCTAssertEqual(body["fromPlace"] as? [Float64], [-122.339414, 47.575837])
    XCTAssertEqual(body["toPlace"] as? [Float64], [-122.347234, 47.651048])
  }

  /// The server measures "nearby" from where the rider boards.
  func testPatternWithBoardingStop() throws {
    let request = try VehiclePositionsClient.urlRequest(
      endpoint: endpoint, from: from, to: to,
      patterns: [
        PatternRequest(
          code: "f-c23-metrokingcounty:100229:0:01",
          boardingStop: LngLat(lng: -122.328957, lat: 47.5933418))
      ])

    let pattern = try patterns(self.body(request))[0]
    XCTAssertEqual(pattern["code"] as? String, "f-c23-metrokingcounty:100229:0:01")
    XCTAssertEqual(pattern["boardingStop"] as? [Float64], [-122.328957, 47.5933418])
  }

  /// Without one the server can't rank, and reports every vehicle on the pattern.
  func testPatternWithoutBoardingStop() throws {
    let request = try VehiclePositionsClient.urlRequest(
      endpoint: endpoint, from: from, to: to,
      patterns: [PatternRequest(code: "f-c23-metrokingcounty:100229:0:01", boardingStop: nil)])

    let pattern = try patterns(self.body(request))[0]
    XCTAssertEqual(pattern["code"] as? String, "f-c23-metrokingcounty:100229:0:01")
    XCTAssertNil(pattern["boardingStop"])
  }

  func testEveryPatternIsAsked() throws {
    let request = try VehiclePositionsClient.urlRequest(
      endpoint: endpoint, from: from, to: to,
      patterns: [
        PatternRequest(code: "1:40:0:01", boardingStop: LngLat(lng: -122.33, lat: 47.6)),
        PatternRequest(code: "1:21:0:01", boardingStop: nil),
      ])

    let codes = try patterns(self.body(request)).map { $0["code"] as? String }
    XCTAssertEqual(codes, ["1:40:0:01", "1:21:0:01"])
  }

  func testItPostsToTheEndpoint() throws {
    let request = try VehiclePositionsClient.urlRequest(
      endpoint: endpoint, from: from, to: to, patterns: [])

    XCTAssertEqual(request.httpMethod, "POST")
    XCTAssertEqual(request.url?.path(), "/travelmux/v8/vehicle_positions")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
  }
}
