//
//  VehiclePositionsClient.swift
//  maps.earth
//
//  Created by Michael Kirk on 9/17/26.
//

import Foundation

/// A pattern to report vehicles for, and where the rider boards it.
struct PatternRequest: Equatable {
  let code: String
  /// A pattern runs its whole length, and most of its vehicles have nothing to do with the trip,
  /// so travelmux reports only the ones either side of where the rider gets on.
  let boardingStop: LngLat?

  var asQueryValue: String {
    guard let boardingStop else {
      return code
    }
    return "\(code)@\(boardingStop.lat),\(boardingStop.lng)"
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
  /// Where the vehicles near each requested pattern's boarding stop are right now.
  ///
  /// `from`/`to` are the endpoints of the plan the patterns came from: a pattern code only means
  /// something to the transit graph that issued it, and these pick the same one.
  func query(from: LngLat, to: LngLat, patterns: [PatternRequest]) async throws
    -> VehiclePositionsResponse
  {
    let queryItems = [
      URLQueryItem(name: "fromPlace", value: "\(from.lat),\(from.lng)"),
      URLQueryItem(name: "toPlace", value: "\(to.lat),\(to.lng)"),
      URLQueryItem(
        name: "patterns",
        value: patterns.map { $0.asQueryValue }.joined(separator: ";")),
    ]
    let url = AppConfig().travelmuxEndpoint.appending(path: "vehicle_positions").appending(
      queryItems: queryItems)

    let (data, response) = try await URLSession.shared.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw VehiclePositionsError.requestFailed(
        statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    return try JSONDecoder.travelmux.decode(VehiclePositionsResponse.self, from: data)
  }
}

enum VehiclePositionsError: Error {
  case requestFailed(statusCode: Int)
}
