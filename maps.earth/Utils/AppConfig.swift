//
//  AppConfig.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/7/24.
//

import Foundation

struct AppConfig {
  let onlineServerBase = URL(string: "https://maps.earth")!
  // let serverBase = URL(string: "https://seattle.maps.earth")!
  // let serverBase = URL(string: "http://localhost:9000")!
  // let serverBase = URL(string: "https://dev.maps.earth")!
  let offlineServerBase = URL(string: "http://localhost:8080")!

  var peliasEndpoint: URL {
    self.onlineServerBase.appending(path: "/pelias/v1/")
  }

  var travelmuxEndpoint: URL {
    self.onlineServerBase.appending(path: "travelmux/v6")
  }

  var valhallaEndpoint: URL {
    self.onlineServerBase.appending(path: "/valhalla/route")
  }

  var onlineTileserverStyleUrl: URL {
    self.onlineServerBase.appending(path: "/tileserver/styles/basic/style.json")
  }

  var offlineTileserverStyleUrl: URL {
    self.offlineServerBase.appending(path: "/tileserver/styles/basic/style.json")
  }

  // static let pmtilesRoot = "https://pub-ac9fe9811d2840258dbf2efb3d236e29.r2.dev/pmtiles"
  static let pmtilesRoot = "https://r2-data.maps.earth/pmtiles"
  // static let pmtilesRoot = "http://127.0.0.1:8001/pmtiles"
  let planetPMTilesURL = "\(pmtilesRoot)/maps-earth-planet-v1.250915.pmtiles"
  let planetOverviewPMTilesURL = "\(pmtilesRoot)/maps-earth-planet-v1.250915-z6.pmtiles"

  func ensureOfflineDirectoryPath() throws -> String {
    let fileManager = FileManager.default
    let documentsDirectory = try fileManager.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )

    // Setup offline tiles directory
    let offlineDirectory = documentsDirectory.appendingPathComponent("offline")
    if !fileManager.fileExists(atPath: offlineDirectory.path) {
      try fileManager.createDirectory(at: offlineDirectory, withIntermediateDirectories: true)
    }
    return offlineDirectory.path
  }
}
