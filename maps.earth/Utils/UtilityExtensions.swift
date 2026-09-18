//
//  UtilityExtensions.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/23/24.
//

import Foundation
import MapLibre

private let logger = FileLogger()

extension Collection {
  subscript(getOrNil index: Index) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}

extension MLNOfflineStorage {
  /// Clears the ambient cache with logging
  func clearAmbientCacheWithLogging(context: String = "") async throws {
    let contextMsg = context.isEmpty ? "" : " (\(context))"
    logger.info("Clearing ambient cache\(contextMsg)")
    do {
      try await clearAmbientCache()
      logger.info("Successfully cleared ambient cache\(contextMsg)")
    } catch {
      logger.error("Failed to clear ambient cache\(contextMsg): \(error)")
      throw error
    }
  }
}

extension JSONDecoder {
  /// Decodes travelmux's RFC 3339 timestamps, with or without fractional seconds.
  static let travelmux: JSONDecoder = {
    let withFractionalSeconds = ISO8601DateFormatter()
    withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let withoutFractionalSeconds = ISO8601DateFormatter()
    withoutFractionalSeconds.formatOptions = [.withInternetDateTime]

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let text = try decoder.singleValueContainer().decode(String.self)
      guard
        let date = withFractionalSeconds.date(from: text)
          ?? withoutFractionalSeconds.date(from: text)
      else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath, debugDescription: "invalid RFC 3339 date: \(text)"))
      }
      return date
    }
    return decoder
  }()
}
