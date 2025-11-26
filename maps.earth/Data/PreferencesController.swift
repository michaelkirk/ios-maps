//
//  PreferencesController.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import Foundation

private let logger = FileLogger()

class Preferences: ObservableObject {

  let controller: PreferencesController

  @MainActor
  static func forTesting(empty: ()) -> Preferences {
    let storage = StorageController.InMemoryForTesting()
    let controller = PreferencesController(fromStorage: storage)
    let record = storage.preferences!
    return Preferences(controller: controller, record: record)
  }

  @MainActor
  static func forTesting(recentSearches: [String] = ["Gym", "Coffee", "123 Fake Street"])
    -> Preferences
  {
    let storage = StorageController.InMemoryForTesting()
    var record = Preferences.Record()
    record.recentSearches = recentSearches
    record.favoritePlaces = [
      FavoritePlace(placeType: .home, lngLat: FixtureData.places[.dubsea].location),
      FavoritePlace(placeType: .work, lngLat: FixtureData.places[.santaLucia].location),
      FavoritePlace(
        placeType: .other("Zeitgeist"), lngLat: FixtureData.places[.zeitgeist].location),
      FavoritePlace(placeType: .other("Real Fine"), lngLat: FixtureData.places[.realfine].location),
    ]
    record.offlineRegions = [
      OfflineRegion(
        name: "San Francisco",
        bounds: BBox(
          top: 37.8199, right: -122.3649, bottom: 37.7249, left: -122.5155),
        createdAt: Date().addingTimeInterval(-86400 * 7),  // 7 days ago
        sizeInBytes: 125_000_000  // ~125 MB
      ),
      OfflineRegion(
        name: "Downtown Seattle",
        bounds: BBox(
          top: 47.6262, right: -122.3121, bottom: 47.5952, left: -122.3559),
        createdAt: Date().addingTimeInterval(-86400 * 2),  // 2 days ago
        sizeInBytes: 87_500_000  // ~87.5 MB
      ),
    ]
    Task {
      try storage.write(preferences: record)
    }
    let controller = PreferencesController(fromStorage: storage)
    return Preferences(controller: controller, record: record)
  }

  @MainActor
  @Published
  var recentSearches: [String] = ["Loading..."]

  @MainActor
  @Published
  var preferredTravelMode: TravelMode = .walk

  @MainActor
  @Published
  var favoritePlaces: [FavoritePlace] = []

  @MainActor
  @Published
  var offlineRegions: [OfflineRegion] = []

  @MainActor
  @Published
  var offlineMode: Bool = false

  @MainActor
  @Published
  var offlineMapFeatureEnabled: Bool = false

  @MainActor
  @Published
  var devMode: Bool = false

  @MainActor
  @Published
  var loaded: Bool = false

  @MainActor
  var tileserverStyleUrl: URL {
    if offlineMode {
      return AppConfig().offlineTileserverStyleUrl
    } else {
      return AppConfig().onlineTileserverStyleUrl
    }
  }

  @MainActor
  static func load(controller: PreferencesController) async throws -> Preferences {
    let record = try await controller.load()
    return await MainActor.run {
      return Preferences(controller: controller, record: record)
    }
  }

  @MainActor
  init(controller: PreferencesController, record: Preferences.Record) {
    self.controller = controller
    self.recentSearches = record.recentSearches
    self.preferredTravelMode = record.preferredTravelMode
    self.favoritePlaces = record.favoritePlaces
    self.offlineRegions = record.offlineRegions
    self.offlineMode = record.offlineMode
    self.offlineMapFeatureEnabled = record.offlineMapFeatureEnabled
    self.devMode = record.devMode
    self.loaded = true
  }

  @MainActor
  func addSearch(text: String) async {
    self.recentSearches = await self.controller.addSearch(text: text)
  }

  @MainActor
  func clearSearch() async {
    self.recentSearches = []
    await self.controller.save(record: self.asRecord)
  }

  @MainActor
  func setPreferredTravelMode(_ travelMode: TravelMode) async {
    self.preferredTravelMode = travelMode
    await self.controller.save(record: self.asRecord)
  }

  @MainActor
  func addFavoritePlace(place: Place, as placeType: FavoritePlace.PlaceType) async {
    let favorite = FavoritePlace(
      placeType: placeType,
      placeId: place.id,
      longitude: place.lng,
      latitude: place.lat
    )
    self.favoritePlaces.append(favorite)
    await self.controller.save(record: self.asRecord)
  }

  @MainActor
  func removeFavoritePlace(place: Place) async {
    self.favoritePlaces = self.favoritePlaces.filter { $0.placeId != place.id }
    await self.controller.save(record: self.asRecord)
  }

  @MainActor
  func setOfflineMode(_ enabled: Bool) async {
    self.offlineMode = enabled
    await self.controller.save(record: self.asRecord)
  }

  @MainActor
  func setOfflineMapFeatureEnabled(_ enabled: Bool) async {
    self.offlineMapFeatureEnabled = enabled
    await self.controller.save(record: self.asRecord)
  }

  @MainActor
  func setDevMode(_ enabled: Bool) async {
    self.devMode = enabled
    await self.controller.save(record: self.asRecord)
  }

  @MainActor
  func addOfflineRegion(_ region: OfflineRegion) async {
    self.offlineRegions.append(region)
    await self.controller.save(record: self.asRecord)
  }

  @MainActor
  func removeOfflineRegion(_ region: OfflineRegion) async {
    self.offlineRegions.removeAll(where: { $0.id == region.id })
    await self.controller.save(record: self.asRecord)
  }

  // MARK: Codable

  @MainActor
  var asRecord: Record {
    return Record(
      schemaVersion: Record.schemaVersion,
      recentSearches: recentSearches,
      preferredTravelMode: preferredTravelMode,
      favoritePlaces: favoritePlaces,
      offlineRegions: offlineRegions,
      offlineMode: offlineMode,
      offlineMapFeatureEnabled: offlineMapFeatureEnabled,
      devMode: devMode
    )
  }

  struct Record: Codable {
    typealias LegacyRecord = RecordV2

    enum MigrationError: Error {
      case unexpectedSchemaVersion(UInt, expected: UInt)

      var localizedDescription: String {
        switch self {
        case .unexpectedSchemaVersion(let actual, let expected):
          return "Unexpected schema version \(actual), expected \(expected)"
        }
      }
    }

    struct RecordV1: Codable {
      var recentSearches: [String] = []
    }

    struct RecordV2: Codable {
      var schemaVersion: UInt
      var recentSearches: [String] = []
      var preferredTravelMode: TravelMode
      var favoritePlaces: [FavoritePlace] = []
      var offlineRegions: [OfflineRegion] = []
      var offlineMode: Bool = false
      var offlineMapFeatureEnabled: Bool = false
      var devMode: Bool = false

      /// Decodes V2, migrating from V1 if necessary
      static func load(jsonData: Data, jsonDecoder: JSONDecoder) throws -> Self {
        do {
          let v2Record = try jsonDecoder.decode(RecordV2.self, from: jsonData)
          return v2Record
        } catch {
          print("error decoding V2 schema: \(error)")
          // Fall back to V1 migration
          let v1Record = try jsonDecoder.decode(RecordV1.self, from: jsonData)
          print("Migrated V1 Preferences record to V2: \(v1Record)")
          return RecordV2(legacyV1: v1Record)
        }
      }

      init(legacyV1: RecordV1) {
        self.schemaVersion = 2
        self.recentSearches = legacyV1.recentSearches
        self.preferredTravelMode = .walk
        self.favoritePlaces = []
        self.offlineRegions = []
        self.offlineMode = false
        self.offlineMapFeatureEnabled = false
        self.devMode = false
      }
    }

    static let schemaVersion: UInt = 3  // Bumped for BBox coordinate fix
    var schemaVersion: UInt
    var recentSearches: [String] = []
    var preferredTravelMode: TravelMode
    var favoritePlaces: [FavoritePlace] = []
    var offlineRegions: [OfflineRegion] = []
    var offlineMode: Bool = false
    var offlineMapFeatureEnabled: Bool = false
    var devMode: Bool = false
    var hasLatestSchemaVersion: Bool {
      self.schemaVersion == Self.schemaVersion
    }

    /// Decodes, migrating if necessary
    static func load(jsonData: Data) throws -> Self {
      let jsonDecoder = JSONDecoder()
      var record: Record
      do {
        record = try jsonDecoder.decode(Self.self, from: jsonData)
        if !record.hasLatestSchemaVersion {
          throw MigrationError.unexpectedSchemaVersion(
            record.schemaVersion, expected: Self.schemaVersion)
        }
      } catch {
        print("error decoding current schema (V3): \(error)")
        // Fall back to V2 migration (which will in turn fall back to V1 if needed)
        let v2Record = try RecordV2.load(jsonData: jsonData, jsonDecoder: jsonDecoder)
        record = Record(legacyV2: v2Record)
        print("Migrated V2 Preferences record to V3 (fixed BBox ordering)")
      }
      return record
    }
  }
}

extension Preferences.Record {
  init() {
    self.recentSearches = []
    self.preferredTravelMode = .walk
    self.schemaVersion = Self.schemaVersion
    self.favoritePlaces = []
    self.offlineRegions = []
    self.offlineMode = false
    self.offlineMapFeatureEnabled = false
    self.devMode = false
  }

  init(legacyV2: RecordV2) {
    self.recentSearches = legacyV2.recentSearches
    self.preferredTravelMode = legacyV2.preferredTravelMode
    self.schemaVersion = Self.schemaVersion
    self.favoritePlaces = legacyV2.favoritePlaces

    // Fix BBox coordinate ordering from V2
    // V2 incorrectly decoded as [top, right, bottom, left]
    // V3+ correctly decodes as [left, bottom, right, top]
    // So we need to swap the decoded values
    self.offlineRegions = legacyV2.offlineRegions.map { region in
      OfflineRegion(
        id: region.id,
        name: region.name,
        bounds: BBox(
          top: region.bounds.left,  // V2's "left" was actually "top"
          right: region.bounds.bottom,  // V2's "bottom" was actually "right"
          bottom: region.bounds.right,  // V2's "right" was actually "bottom"
          left: region.bounds.top  // V2's "top" was actually "left"
        ),
        createdAt: region.createdAt,
        sizeInBytes: region.sizeInBytes,
        fileName: region.fileName
      )
    }

    self.offlineMode = legacyV2.offlineMode
    self.offlineMapFeatureEnabled = legacyV2.offlineMapFeatureEnabled
    self.devMode = legacyV2.devMode
  }
}

actor PreferencesController {
  var storageController: StorageController

  var preferences: Preferences.Record = Preferences.Record()

  init(fromStorage storageController: StorageController) {
    self.storageController = storageController
  }

  func save(record: Preferences.Record) async {
    self.preferences = record
    do {
      try self.storageController.write(preferences: record)
    } catch {
      logger.error("error saving preferences: \(error)")
    }
  }

  func clearSearch() async {
    preferences.recentSearches = []
    await save(record: preferences)
  }

  func addSearch(text: String) async -> [String] {
    var recentSearches = self.preferences.recentSearches
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)

    if let existing = recentSearches.firstIndex(where: {
      $0.lowercased() == text.lowercased()
    }) {
      recentSearches.remove(at: existing)
    }
    recentSearches.reverse()
    recentSearches.append(text)
    recentSearches.reverse()

    // Only keep some of the most recent searches
    let mostRecentSearches = Array(recentSearches.prefix(10))
    logger.debug("New recents: \(mostRecentSearches)")
    self.preferences.recentSearches = mostRecentSearches
    await save(record: preferences)

    return mostRecentSearches
  }

  func load() async throws -> Preferences.Record {
    let preferences = try storageController.readPreferences() ?? Preferences.Record()
    self.preferences = preferences
    return preferences
  }
}
