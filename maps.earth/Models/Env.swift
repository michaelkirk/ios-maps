//
//  Env.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/14/24.
//

import Foundation
import MapLibre

class Env {
  static var current = Env()

  let isMock: Bool
  var tripPlanClient: TripPlanClient
  var storageController: StorageController
  var preferencesController: PreferencesController

  init() {
    isMock = false
    tripPlanClient = TripPlanClient.RealClient()
    storageController = StorageController.OnDisk()
    preferencesController = PreferencesController(fromStorage: storageController)
  }

  init(offlineWithMockData: ()) {
    isMock = true
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
}
