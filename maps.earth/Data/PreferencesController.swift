//
//  PreferencesController.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import Foundation

private let logger = FileLogger()

class Preferences: ObservableObject, Codable {
  @Published
  var recentSearches: [String]

  init() {
    self.recentSearches = []
  }

  init(recentSearches: [String]) {
    self.recentSearches = recentSearches
  }

  // MARK: Codable
  // Annoying boiler plate betweeen ObservableObject and Codable
  struct Record: Codable {
    var recentSearches: [String] = []
  }

  required init(from decoder: any Decoder) throws {
    let record = try Record.init(from: decoder)
    self.recentSearches = record.recentSearches
  }

  func encode(to encoder: any Encoder) throws {
    let record = Record(recentSearches: recentSearches)
    try record.encode(to: encoder)
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
    self.serialQueue.async {
      do {
        try self.storageController.write(preferences: self.preferences)
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
        recentSearches = Array(recentSearches.prefix(10))
        logger.debug("New recents: \(recentSearches)")

        DispatchQueue.main.async {
          self.preferences.recentSearches = recentSearches
          self.serialQueue.async {
            do {
              try self.storageController.write(preferences: self.preferences)
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
