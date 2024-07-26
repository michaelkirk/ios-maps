//
//  PreferencesController.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import Foundation

private let logger = FileLogger()

class Preferences: ObservableObject, Decodable {
  @Published
  var recentSearches: [String]
  var preferredTravelMode: TravelMode

  init() {
    self.recentSearches = []
    self.preferredTravelMode = .walk
  }

  init(recentSearches: [String], preferredMode: TravelMode) {
    self.recentSearches = recentSearches
    self.preferredTravelMode = preferredMode
  }

  init(record: Record) {
    self.recentSearches = record.recentSearches
    self.preferredTravelMode = record.preferredTravelMode
  }

  required init(from decoder: any Decoder) throws {
    let record: Record
    do {
      record = try Record.init(from: decoder)
      assert(record.hasLatestSchemaVersion)
    } catch {
      let legacyRecord = try Record.LegacyRecord.init(from: decoder)
      record = Record(legacy: legacyRecord)
      print("Migrated legacy Preferences record \(legacyRecord), newRecord: \(record)")
    }
    self.recentSearches = record.recentSearches
    self.preferredTravelMode = record.preferredTravelMode
  }

  var asRecord: Record {
    dispatchPrecondition(condition: .onQueue(.main))
    return Record(
      schemaVersion: Record.schemaVersion, recentSearches: recentSearches,
      preferredTravelMode: preferredTravelMode)
  }

  // MARK: Codable
  // Annoying boiler plate betweeen ObservableObject and Codable
  struct Record: Codable {
    struct RecordV1: Codable {
      var recentSearches: [String] = []
    }
    typealias LegacyRecord = RecordV1
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
  init(legacy: Self.LegacyRecord) {
    self.recentSearches = legacy.recentSearches
    self.preferredTravelMode = .walk
    self.schemaVersion = Self.schemaVersion
  }
}

class PreferencesController {
  let serialQueue = DispatchQueue(label: "RecentsController")
  var storageController: StorageController

  var preferences: Preferences

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

  func clear() {
    AssertMainThread()
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

  func setPreferredTravelMode(_ travelMode: TravelMode) {
    dispatchPrecondition(condition: .onQueue(.main))
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

  func addSearch(text: String) async throws {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    try await withCheckedThrowingContinuation { continuation in
      self.serialQueue.async {
        var recentSearches = self.preferences.recentSearches
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
              continuation.resume(throwing: error)
            }
          }
        }
      }
    }
  }
}
