//
//  Env.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/14/24.
//

import FerrostarCore
import Foundation
import HeadwayFFI
import MapLibre
import MapboxDirections

@MainActor
class Env {
  // call `load` before assigning
  @MainActor
  static var current: Env!

  let isMock: Bool
  var tripPlanClient: TripPlanClient
  var storageController: StorageController
  var preferencesController: PreferencesController
  var preferences: Preferences!
  var headwayServer: HeadwayServer!
  var mlnDirections: Directions {
    travelmuxDirectionsService
    //    valhallaDirectionsService
    //     mapboxDirectionsService
  }

  func load() async throws {
    let headwayServer = try await Task {
      let storageDir = try AppConfig().ensureOfflineDirectoryPath()
      // Create server instance (now synchronous with internal runtime)
      return try await HeadwayServer(
        storageDir: storageDir,
        extractSourceUrl: AppConfig().planetPMTilesURL
      )
    }.value
    self.headwayServer = headwayServer
    self.preferences = try await Preferences.load(controller: preferencesController)
  }

  lazy var mapboxDirectionsService: Directions = Directions.shared
  lazy var travelmuxDirectionsService: Directions = Directions(
    accessToken: "fake-token", host: AppConfig().travelmuxEndpoint.host())
  lazy var valhallaDirectionsService: Directions = Directions(
    accessToken: "fake-token", host: AppConfig().valhallaEndpoint.host())

  let simulateLocationForTesting: Bool
  lazy var coreLocationProvider: CoreLocationProvider = CoreLocationProvider(
    activityType: .other, allowBackgroundLocationUpdates: false)

  let offlineTileserverStyleUrl = URL(
    string: "http://127.0.0.1:8080/tileserver/styles/basic/style.json")!

  @MainActor
  init() {
    isMock = false
    simulateLocationForTesting = Platform.isSimulator
    tripPlanClient = TripPlanClient.RealClient()
    storageController = StorageController.OnDisk()
    preferencesController = PreferencesController(fromStorage: storageController)
  }

  @MainActor
  init(offlineWithMockData: ()) {
    isMock = true
    simulateLocationForTesting = true
    tripPlanClient = TripPlanClient.MockClient()
    let storageController = StorageController.InMemoryForTesting()
    self.storageController = storageController
    preferencesController = PreferencesController(fromStorage: storageController)
    preferences = Preferences(
      controller: preferencesController, record: storageController.preferences!)
    // TODO
    // server =
  }

  /// Main thread only
  var getMapFocus: () -> LngLat? {
    get {
      AssertMainThread()
      return self._getMapFocus
    }
    set {
      AssertMainThread()
      self._getMapFocus = newValue
    }
  }
  private var _getMapFocus: () -> LngLat? = { nil }

  /// We need a dynamic closure, rather than just assigning the camera "by reference" once upon initialization because `mlnMap.camera` is copy.
  ///
  /// NOTE: Main thread only
  var getMapCamera: () -> MLNMapCamera? {
    get {
      AssertMainThread()
      return self._getMapCamera
    }
    set {
      AssertMainThread()
      self._getMapCamera = newValue
    }
  }
  private var _getMapCamera: () -> MLNMapCamera? = { nil }

  /// Main thread only
  var getMapView: () -> MLNMapView? {
    get {
      AssertMainThread()
      return self._getMapView
    }
    set {
      AssertMainThread()
      self._getMapView = newValue
    }
  }
  private var _getMapView: () -> MLNMapView? = { nil }

  private var _activeRouteNavigation: RouteNavigation? = nil
  var activeRouteNavigation: RouteNavigation? {
    get {
      AssertMainThread()
      return _activeRouteNavigation
    }
    set {
      AssertMainThread()
      _activeRouteNavigation = newValue
    }
  }

  /// Main thread only - trigger a map refresh
  var refreshMap: ((MLNCoordinateBounds?) -> Void)! {
    get {
      AssertMainThread()
      return self._refreshMap
    }
    set {
      AssertMainThread()
      self._refreshMap = newValue
    }
  }
  private var _refreshMap: ((MLNCoordinateBounds?) -> Void)? = nil
}
