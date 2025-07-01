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
  static let shared: Preferences = Preferences(controller: Env.current.preferencesController)

  @MainActor
  @Published
  var recentSearches: [String] = ["Loading..."]

  @MainActor
  @Published
  var preferredTravelMode: TravelMode = .walk

  @MainActor
  init(controller: PreferencesController) {
    self.controller = controller
    Task {
      let record = try await self.controller.load()
      self.recentSearches = record.recentSearches
      self.preferredTravelMode = record.preferredTravelMode
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

  // MARK: Codable

  @MainActor
  var asRecord: Record {
    return Record(
      schemaVersion: Record.schemaVersion, recentSearches: recentSearches,
      preferredTravelMode: preferredTravelMode)
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
  }

  init(legacy: Self.LegacyRecord) {
    self.recentSearches = legacy.recentSearches
    self.preferredTravelMode = .walk
    self.schemaVersion = Self.schemaVersion
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

  func setPreferredTravelMode(_ travelMode: TravelMode) async {
    guard preferences.preferredTravelMode != travelMode else {
      return
    }
    preferences.preferredTravelMode = travelMode
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
