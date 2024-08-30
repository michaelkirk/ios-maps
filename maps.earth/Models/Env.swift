//
//  Env.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/14/24.
//

import FerrostarCore
import Foundation
import MapLibre
import MapboxDirections

let stadiaMapsAPIKey = "7275abbb-7c77-4c26-b4dd-31a1a51180e1"

// Configure the navigation session.
// You have a lot of flexibility here based on your use case.
let config = SwiftNavigationControllerConfig(
  stepAdvance: .relativeLineStringDistance(
    minimumHorizontalAccuracy: 32, automaticAdvanceDistance: 10),
  routeDeviationTracking: .staticThreshold(
    minimumHorizontalAccuracy: 25, maxAcceptableDeviation: 20)
)

class Env {
  @MainActor
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

  // TODO: If you reset this, you'll need to also reset ferrostarCore
  lazy var locationProvider: LocationProviding = SimulatedLocationProvider()
  lazy var ferrostarCore: FerrostarCore = try! FerrostarCore(
    valhallaEndpointUrl: URL(
      string: "https://api.stadiamaps.com/route/v1?api_key=\(stadiaMapsAPIKey)"
    )!,
    profile: "bicycle",
    locationProvider: locationProvider,
    navigationControllerConfig: config,
    costingOptions: ["bicycle": ["use_roads": 0.2]]
  )

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
