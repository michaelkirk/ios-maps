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
