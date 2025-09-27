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
  static var shared: Preferences {
    Preferences(controller: Env.current.preferencesController)
  }

  @MainActor
  static func forTesting(empty: ()) -> Preferences {
    let storage = StorageController.InMemoryForTesting()
    let controller = PreferencesController(fromStorage: storage)
    return Preferences(controller: controller)
  }

  @MainActor
  static func forTesting(recentSearches: [String] = ["Gym", "Coffee", "123 Fake Street"])
    -> Preferences
  {
    let storage = StorageController.InMemoryForTesting()
    var preferences = Preferences.Record()
    preferences.recentSearches = recentSearches
    preferences.favoritePlaces = [
      FavoritePlace(placeType: .home, lngLat: FixtureData.places[.dubsea].location),
      FavoritePlace(placeType: .work, lngLat: FixtureData.places[.santaLucia].location),
      FavoritePlace(
        placeType: .other("Zeitgeist"), lngLat: FixtureData.places[.zeitgeist].location),
      FavoritePlace(placeType: .other("Real Fine"), lngLat: FixtureData.places[.realfine].location),
    ]
    Task {
      try storage.write(preferences: preferences)
    }
    let controller = PreferencesController(fromStorage: storage)
    return Preferences(controller: controller)
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
  init(controller: PreferencesController) {
    self.controller = controller
    Task {
      let record = try await self.controller.load()
      self.recentSearches = record.recentSearches
      self.preferredTravelMode = record.preferredTravelMode
      self.favoritePlaces = record.favoritePlaces
    }
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

  // MARK: Codable

  @MainActor
  var asRecord: Record {
    return Record(
      schemaVersion: Record.schemaVersion,
      recentSearches: recentSearches,
      preferredTravelMode: preferredTravelMode,
      favoritePlaces: favoritePlaces
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
  }

  init(legacy: Self.LegacyRecord) {
    self.recentSearches = legacy.recentSearches
    self.preferredTravelMode = .walk
    self.schemaVersion = Self.schemaVersion
    self.favoritePlaces = []
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
