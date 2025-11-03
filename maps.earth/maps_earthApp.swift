//
//  maps_earthApp.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import HeadwayFFI
import MapLibre
import SwiftUI

private let logger = FileLogger()

@main
struct maps_earthApp: App {
  var body: some Scene {
    WindowGroup {
      AppWithEnv()
    }
  }
}

struct AppWithEnv: View {
  @State
  var error: Swift.Error? = nil

  @State
  var isLoaded: Bool = false

  func load() async throws {
    // Enable logging for the headway lib
    enableLogging(subsystem: "headway.earth.maps", logLevel: .info)

    Env.current = try await Task {
      let env = Env()
      try await env.load()
      return env
    }.value

    // Download overview map if offline maps feature is enabled
    if Env.current.preferences.offlineMapFeatureEnabled {
      await OfflineRegionManager.downloadOverviewMap()
    }

    Thread.detachNewThread {
      Task {
        // Start the tileserver
        try await Env.current.headwayServer.start(bindAddr: "127.0.0.1:8080")
      }
    }

    guard let response = try await testLocalServer() else {
      throw AssertionError("Local server startup was missing status")
    }
    print("✅ local server started with status: \(response)")
  }

  var body: some View {
    HStack {
      if let error {
        Text("Error: \(error.localizedDescription)")
      } else if isLoaded {
        HomeView().environmentObject(Env.current.preferences)
      } else {
        Text("Loading...")
      }
    }.task {
      do {
        try await self.load()
        isLoaded = true
      } catch {
        self.error = error
      }
    }
  }
}

// Test the server
func testLocalServer() async throws -> String? {
  let url = URL(string: "http://127.0.0.1:8080/status")!
  let (data, _) = try await URLSession.shared.data(from: url)
  return String(data: data, encoding: .utf8)
}

struct AssertionError: Swift.Error, CustomStringConvertible {
  let description: String
  init(_ message: String) {
    assertionFailure(message)
    self.description = message
  }
}
