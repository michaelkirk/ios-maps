//
//  StorageController.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/16/24.
//

import Foundation

protocol StorageController {
  typealias OnDisk = OnDiskStorage
  typealias InMemoryForTesting = InMemoryStorage

  func write(preferences: Preferences.Record) throws
  func readPreferences() throws -> Preferences?
}

class InMemoryStorage: StorageController {
  var preferences: Preferences? = nil

  @MainActor
  func write(preferences: Preferences.Record) throws {
    dispatchPrecondition(condition: .notOnQueue(.main))
    self.preferences = Preferences(record: preferences)
  }

  func readPreferences() throws -> Preferences? {
    self.preferences
  }
}

class OnDiskStorage: StorageController {
  let fileRoot: URL

  init() {
    guard
      var fileRoot = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    else {
      fatalError("Unexpectedly failed to access user document directory")
    }
    fileRoot.append(path: "AppStorage")
    self.fileRoot = fileRoot
  }

  var preferencesURL: URL {
    fileRoot.appending(path: "preferences.dat")
  }

  func write(preferences: Preferences.Record) throws {
    dispatchPrecondition(condition: .notOnQueue(.main))
    try Bench(title: "write preferences") {
      try self.write(codable: preferences, to: preferencesURL)
    }
  }

  private func write<C: Codable>(codable: C, to url: URL) throws {
    dispatchPrecondition(condition: .notOnQueue(.main))
    precondition(url.isFileURL)

    let parentDir = url.deletingLastPathComponent()
    try! FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

    let jsonEncoder = JSONEncoder()
    let jsonData = try jsonEncoder.encode(codable)
    try jsonData.write(to: preferencesURL, options: [.completeFileProtection])
  }

  func readPreferences() throws -> Preferences? {
    try Bench(title: "read preferences") {
      let jsonDecoder = JSONDecoder()
      guard FileManager.default.fileExists(atPath: preferencesURL.path) else {
        return nil
      }
      let jsonData = try Data(contentsOf: preferencesURL)
      return try jsonDecoder.decode(Preferences.self, from: jsonData)
    }
  }
}
