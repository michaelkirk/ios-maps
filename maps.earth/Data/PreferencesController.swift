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
    typealias LegacyRecord = RecordV1
    struct RecordV1: Codable {
      var recentSearches: [String] = []
    }

    static let schemaVersion: UInt = 2
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
      let record: Record
      do {
        record = try jsonDecoder.decode(Self.self, from: jsonData)
        assert(record.hasLatestSchemaVersion)
      } catch {
        print("error: \(error)")
        let legacyRecord = try jsonDecoder.decode(Self.LegacyRecord.self, from: jsonData)
        record = Record(legacy: legacyRecord)
        print("Migrated legacy Preferences record \(legacyRecord), newRecord: \(record)")
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

  init(legacy: Self.LegacyRecord) {
    self.recentSearches = legacy.recentSearches
    self.preferredTravelMode = .walk
    self.schemaVersion = Self.schemaVersion
    self.favoritePlaces = []
    self.offlineRegions = []
    self.offlineMode = false
    self.offlineMapFeatureEnabled = false
    self.devMode = false
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
