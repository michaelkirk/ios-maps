import Foundation
import HeadwayFFI
import MapLibre

private let logger = FileLogger()

struct OfflineRegionManager {
  let preferences: Preferences

  @MainActor
  static var headwayServer: HeadwayServer {
    Env.current.headwayServer!
  }

  /// Downloads the planet overview PMTiles file if not already present.
  /// Returns true if a new map was downloaded.
  @MainActor
  static func downloadOverviewMap() async -> Bool {
    do {
      let wasDownloaded = try await headwayServer.downloadSystemPmtilesIfNecessary(
        sourceUrl: AppConfig().planetOverviewPMTilesURL,
        destinationFilename: "planet-overview.pmtiles")

      if wasDownloaded {
        // Clear the tile cache so the map will reload tiles from the tileserver
        // which now includes the newly downloaded overview map
        try? await MLNOfflineStorage.shared.clearAmbientCacheWithLogging(
          context: "after downloading overview map")
      }

      return wasDownloaded
    } catch {
      logger.error("Failed to download planet overview PMTiles: \(error)")
      return false
    }
  }

  @MainActor
  func createOfflineRegion(
    name: String,
    bounds: BBox,
    styleURL: URL,
    extractionPlan: ExtractionPlan,
    progressCallback: ExtractProgress? = nil
  ) async throws -> OfflineRegion {
    var region = OfflineRegion(
      name: name,
      bounds: bounds
    )

    // Run extraction on background thread since it's a long-running operation
    let regionRecord = try await Task.detached(priority: .userInitiated) {
      try await Self.headwayServer.extractPmtilesRegion(
        plan: extractionPlan,
        progressCallback: progressCallback
      )
    }.value

    region.fileName = regionRecord.fileName()
    region.sizeInBytes = regionRecord.fileSize()

    // Clear the tile cache so the map will reload tiles from the tileserver
    // which now includes the newly downloaded region
    try? await MLNOfflineStorage.shared.clearAmbientCacheWithLogging(
      context: "after creating offline region")

    return region
  }

  @MainActor
  func deleteOfflineRegion(_ region: OfflineRegion) async throws {
    guard let fileName = region.fileName else {
      assertionFailure("Trying to delete region which was never saved")
      return
    }
    logger.info("deleting region \(region.name) at \(fileName)")
    try await Self.headwayServer.removePmtilesExtract(fileName: fileName)

    // Clear the tile cache so the map will reload tiles without the deleted region
    try? await MLNOfflineStorage.shared.clearAmbientCacheWithLogging(
      context: "after deleting offline region")
    Env.current.refreshMap(nil)
  }
}
