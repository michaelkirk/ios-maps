//
//  Env.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/14/24.
//

import Foundation
import MapLibre
import MapboxDirections

class Env {
  static var current = Env()

  let isMock: Bool
  var tripPlanClient: TripPlanClient
  var storageController: StorageController
  var preferencesController: PreferencesController
  var mlnDirections: Directions {
    travelmuxDirectionsService
    //    valhallaDirectionsService
    //     mapboxDirectionsService
  }

  lazy var mapboxDirectionsService: Directions = Directions.shared
  lazy var travelmuxDirectionsService: Directions = Directions(
    accessToken: "fake-token", host: AppConfig().travelmuxEndpoint.host())
  lazy var valhallaDirectionsService: Directions = Directions(
    accessToken: "fake-token", host: AppConfig().valhallaEndpoint.host())

  let simulateLocationForTesting: Bool

  init() {
    isMock = false
    simulateLocationForTesting = Platform.isSimulator
    tripPlanClient = TripPlanClient.RealClient()
    storageController = StorageController.OnDisk()
    preferencesController = PreferencesController(fromStorage: storageController)
  }

  init(offlineWithMockData: ()) {
    isMock = true
    simulateLocationForTesting = true
    tripPlanClient = TripPlanClient.MockClient()
    storageController = StorageController.InMemoryForTesting()
    preferencesController = PreferencesController(fromStorage: storageController)
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

  /// Main thread only
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
}
