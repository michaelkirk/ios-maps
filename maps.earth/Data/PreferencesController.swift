//
//  PreferencesController.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import Foundation

private let logger = FileLogger()

class Preferences: ObservableObject, Decodable {
  @MainActor
  @Published
  var recentSearches: [String]

  @MainActor
  @Published
  var preferredTravelMode: TravelMode

  @MainActor
  convenience init() {
    self.init(record: Record())
  }

  @MainActor
  init(record: Record) {
    self.recentSearches = record.recentSearches
    self.preferredTravelMode = record.preferredTravelMode
  }

  @MainActor
  required convenience init(from decoder: any Decoder) throws {
    let record: Record
    do {
      record = try Record.init(from: decoder)
      assert(record.hasLatestSchemaVersion)
    } catch {
      let legacyRecord = try Record.LegacyRecord.init(from: decoder)
      record = Record(legacy: legacyRecord)
      print("Migrated legacy Preferences record \(legacyRecord), newRecord: \(record)")
    }
    self.init(record: record)
  }

  @MainActor
  var asRecord: Record {
    return Record(
      schemaVersion: Record.schemaVersion, recentSearches: recentSearches,
      preferredTravelMode: preferredTravelMode)
  }

  // MARK: Codable
  // Annoying boiler plate betweeen ObservableObject and Codable
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

class PreferencesController {
  let serialQueue = DispatchQueue(label: "RecentsController")
  var storageController: StorageController

  @MainActor
  var preferences: Preferences

  @MainActor
  init(fromStorage storageController: StorageController) {
    AssertMainThread()
    self.storageController = storageController
    do {
      self.preferences = try storageController.readPreferences() ?? Preferences()
    } catch {
      assertionFailure("error loading preferences. \(error)")
      logger.error("error loading preferences. \(error)")
      self.preferences = Preferences()
    }
  }

  @MainActor
  func clear() {
    preferences.recentSearches = []
    let record = preferences.asRecord
    self.serialQueue.async {
      do {
        try self.storageController.write(preferences: record)
      } catch {
        logger.error("error saving preferences: \(error)")
      }
    }
  }

  @MainActor
  func setPreferredTravelMode(_ travelMode: TravelMode) {
    guard self.preferences.preferredTravelMode != travelMode else {
      return
    }
    self.preferences.preferredTravelMode = travelMode
    let record = self.preferences.asRecord
    self.serialQueue.async {
      do {
        try self.storageController.write(preferences: record)
      } catch {
        logger.error("error saving preferences: \(error)")
      }
    }
  }

  @MainActor
  func addSearch(text: String) async {
    var recentSearches = self.preferences.recentSearches
    await withCheckedContinuation { continuation in
      self.serialQueue.async {
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

        DispatchQueue.main.async {
          self.preferences.recentSearches = mostRecentSearches
          let record = self.preferences.asRecord

          self.serialQueue.async {
            do {
              try self.storageController.write(preferences: record)
              continuation.resume()
            } catch {
              logger.error("error saving preferences: \(error)")
              continuation.resume()
            }
          }
        }
      }
    }
  }
}
