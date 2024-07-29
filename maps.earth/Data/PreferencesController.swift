//
//  PreferencesController.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import Foundation

private let logger = FileLogger()

// This fancy "immutable record" pattern has broken the "press clear" functionality in that the screen isn't updated (if you restart the app though, the choices are gone)
class Preferences: ObservableObject, Decodable {
  var _record: Record
  var record: Record {
    get {
      AssertMainThread()
      return self._record
    }
    set {
      AssertMainThread()
      self._record = newValue
    }
  }

  var recentSearches: [String] {
    get { self.record.recentSearches }
    set { self.record.recentSearches = newValue }
  }

  var preferredTravelMode: TravelMode {
    get { self.record.preferredTravelMode }
    set { self.record.preferredTravelMode = newValue }
  }

  init() {
    self._record = Record()
  }

  init(record: Record) {
    self._record = record
  }

  required init(from decoder: any Decoder) throws {
    do {
      _record = try Record.init(from: decoder)
      assert(record.hasLatestSchemaVersion)
    } catch {
      let legacyRecord = try Record.LegacyRecord.init(from: decoder)
      _record = Record(legacy: legacyRecord)
      print("Migrated legacy Preferences record \(legacyRecord), newRecord: \(record)")
    }
  }

  var asRecord: Record {
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
    AssertMainThread()
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

  func addSearch(text: String) {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    var recentSearches = self.preferences.recentSearches
    self.serialQueue.async {
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
          } catch {
            logger.error("error saving preferences: \(error)")
          }
        }
      }
    }
  }
}
