//
//  PreferencesController.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import Foundation

private let logger = FileLogger()

class Preferences: ObservableObject {
  @Published
  var recentSearches: [String] = []
}

class PreferencesController {
  static let shared: PreferencesController = PreferencesController()

  let serialQueue = DispatchQueue(label: "RecentsController")
  var preferences: Preferences
  init() {
    self.preferences = Preferences()
  }

  public func loadFromStorage() {
    AssertMainThread()
    self.serialQueue.sync {
      let recents = self.fetch()
      self.preferences.recentSearches = recents
    }
  }

  enum SerializationKeys: String {
    case recentSearchesKey = "kPreferences_recentSearches"
  }

  private func fetch() -> [String] {
    dispatchPrecondition(condition: .onQueue(self.serialQueue))
    guard let existing = UserDefaults.standard.object(forKey: SerializationKeys.recentSearchesKey.rawValue) else {
      return []
    }
    guard let recentSearches = existing as? [String] else {
      return []
    }
    return recentSearches
  }

  private func save(recentSearches: [String]) {
    dispatchPrecondition(condition: .onQueue(self.serialQueue))
    logger.debug("saving")
    UserDefaults.standard.setValue(recentSearches, forKey: SerializationKeys.recentSearchesKey.rawValue)
  }

  func clear() {
    AssertMainThread()
    preferences.recentSearches = []
    self.serialQueue.async {
      logger.debug("clearing")
      UserDefaults.standard.removeObject(forKey: SerializationKeys.recentSearchesKey.rawValue)
    }
  }

  func addSearch(text: String) {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    AssertMainThread()
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
      recentSearches = Array(recentSearches.prefix(5))

      logger.debug("New recents: \(recentSearches)")

      self.save(recentSearches: recentSearches)
      DispatchQueue.main.async {
        // Keep only 5 searches
        self.preferences.recentSearches = recentSearches
      }
    }
  }
}
