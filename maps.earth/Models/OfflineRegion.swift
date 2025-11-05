import Foundation
import MapLibre

struct OfflineRegion: Codable, Identifiable, Equatable {
  var id: String
  var name: String
  var bounds: BBox
  var createdAt: Date
  var sizeInBytes: UInt64?
  var fileName: String?

  init(
    id: String = UUID().uuidString, name: String, bounds: BBox,
    createdAt: Date = Date(), sizeInBytes: UInt64? = nil, fileName: String? = nil
  ) {
    self.id = id
    self.name = name
    self.bounds = bounds
    self.createdAt = createdAt
    self.sizeInBytes = sizeInBytes
    self.fileName = fileName
  }
}
