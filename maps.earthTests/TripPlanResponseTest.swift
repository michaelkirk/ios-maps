//
//  TripPlanResponseTest.swift
//  maps.earthTests
//

import XCTest

@testable import maps_earth

/// What `fetchData` does with a body, given the status it arrived with.
final class TripPlanResponseTest: XCTestCase {
  struct Payload: Decodable, Equatable {
    let itineraries: [String]
  }

  func decode(_ body: String, statusCode: Int) throws -> Result<Payload, TripPlanErrorResponse> {
    try TripPlanNetworkClient.decode(
      data: Data(body.utf8), statusCode: statusCode)
  }

  func testSuccess() throws {
    let result = try decode(#"{"itineraries": ["a"]}"#, statusCode: 200)

    XCTAssertEqual(try result.get(), Payload(itineraries: ["a"]))
  }

  /// travelmux describes its own failures in JSON, and those still come back as a failure the
  /// UI can read rather than as a thrown error.
  func testTravelmuxErrorIsDecoded() throws {
    let body = #"{"error": {"statusCode": 400, "errorCode": 1701, "message": "no coverage"}}"#
    let result = try decode(body, statusCode: 400)

    switch result {
    case .success:
      XCTFail("expected a failure")
    case .failure(let error):
      XCTAssertEqual(error.error.message, "no coverage")
    }
  }

  /// When the service is down, nginx answers for it with an HTML error page. Decoding that as
  /// travelmux's error type reported a corrupt payload, which reads as a bug in the app rather
  /// than the outage it is.
  func testGatewayHtmlSaysWhatHappened() {
    let html =
      "<html>\r\n<head><title>502 Bad Gateway</title></head>\r\n<body>\r\n</body>\r\n</html>"

    XCTAssertThrowsError(try decode(html, statusCode: 502)) { error in
      guard let error = error as? TripPlanServerError else {
        return XCTFail("expected a TripPlanServerError, got \(error)")
      }
      XCTAssertEqual(error.statusCode, 502)
      XCTAssertTrue(
        error.description.contains("502"), "should name the status: \(error.description)")
      XCTAssertTrue(
        error.description.contains("Bad Gateway"),
        "should quote the body so it's obvious what answered: \(error.description)")
    }
  }

  func testEmptyBodySaysSo() {
    XCTAssertThrowsError(try decode("", statusCode: 504)) { error in
      guard let error = error as? TripPlanServerError else {
        return XCTFail("expected a TripPlanServerError, got \(error)")
      }
      XCTAssertTrue(error.description.contains("empty"), error.description)
    }
  }

  /// A 200 that isn't JSON is still a decoding failure - the body claimed to be the real thing.
  func testHtmlWithA200IsADecodingError() {
    XCTAssertThrowsError(try decode("<html></html>", statusCode: 200)) { error in
      XCTAssertTrue(error is DecodingError, "got \(error)")
    }
  }
}
