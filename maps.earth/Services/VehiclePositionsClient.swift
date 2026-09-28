//
//  VehiclePositionsClient.swift
//  maps.earth
//
//  Created by Michael Kirk on 9/17/26.
//

import Foundation

private let logger = FileLogger()

/// A pattern to report vehicles for, and where the rider boards it.
struct PatternRequest: Equatable, Encodable {
  let code: String
  /// A pattern runs its whole length, and most of its vehicles have nothing to do with the trip,
  /// so travelmux reports only the ones either side of where the rider gets on.
  let boardingStop: LngLat?

  private enum CodingKeys: String, CodingKey {
    case code
    case boardingStop
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(code, forKey: .code)
    try container.encodeIfPresent(boardingStop.map(LonLatPair.init), forKey: .boardingStop)
  }
}

/// What gets posted: the endpoints of the plan the patterns came from, and the patterns.
struct VehiclePositionsRequest: Encodable, Equatable {
  let fromPlace: LonLatPair
  let toPlace: LonLatPair
  let patterns: [PatternRequest]

  init(from: LngLat, to: LngLat, patterns: [PatternRequest]) {
    self.fromPlace = LonLatPair(from)
    self.toPlace = LonLatPair(to)
    self.patterns = patterns
  }
}

struct VehiclePositionsResponse: Decodable {
  let vehicles: [TransitVehicle]
  /// The server's own clock, so a device whose clock is off doesn't walk every track from the
  /// wrong end.
  let serverTime: Date
  /// Patterns the transit graph has never heard of, which usually means the plan they came from
  /// predates a rebuild. Absent when they were all recognized.
  let unknownPatterns: [String]?
}

struct VehiclePositionsClient {
  /// Separated from the fetching so the request can be tested without a server.
  internal static func urlRequest(
    endpoint: URL, from: LngLat, to: LngLat, patterns: [PatternRequest]
  ) throws -> URLRequest {
    var request = URLRequest(url: endpoint.appending(path: "vehicle_positions"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      VehiclePositionsRequest(from: from, to: to, patterns: patterns))
    return request
  }

  /// Where the vehicles near each requested pattern's boarding stop are right now.
  ///
  /// `from`/`to` are the endpoints of the plan the patterns came from: a pattern code only means
  /// something to the transit graph that issued it, and these pick the same one.
  func query(from: LngLat, to: LngLat, patterns: [PatternRequest]) async throws
    -> VehiclePositionsResponse
  {
    let request = try Self.urlRequest(
      endpoint: AppConfig().travelmuxV8Endpoint, from: from, to: to, patterns: patterns)

    let url = request.url?.absoluteString ?? ""
    let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    logger.info(
      "travelmux vehicle positions request: POST \(url, privacy: .public) \(body, privacy: .public)"
    )

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
      let responseBody = String(data: data, encoding: .utf8) ?? ""
      logger.warning(
        "travelmux vehicle positions failed: \(statusCode) \(responseBody, privacy: .public)")
      throw VehiclePositionsError.requestFailed(statusCode: statusCode)
    }

    let vehiclePositions = try JSONDecoder.travelmux.decode(
      VehiclePositionsResponse.self, from: data)
    logger.info("travelmux vehicle positions response: \(vehiclePositions.vehicles.count) vehicles")
    return vehiclePositions
  }
}

enum VehiclePositionsError: Error {
  case requestFailed(statusCode: Int)
}
