//
//  TripPlan.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/8/24.
//

import Foundation
import MapboxDirections

// TODO: split this into something like TripQuery and TripResponse
//       since many of these fields will be blank.
@MainActor
class TripPlan: ObservableObject {
  @Published
  @MainActor
  var navigateFrom: Place?

  @Published
  @MainActor
  var navigateTo: Place?

  @Published
  @MainActor var mode: TravelMode {
    didSet {
      Env.current.preferencesController.setPreferredTravelMode(mode)
    }
  }
  @Published @MainActor var transitWithBike: Bool = false
  @Published @MainActor var bounds: Bounds?
  @Published @MainActor var trips: Result<[Trip], Error>
  @Published @MainActor var selectedTrip: Trip?
  @Published @MainActor var selectedRoute: Result<Route, Error>?

  @MainActor
  init(
    from fromPlace: Place? = nil,
    to toPlace: Place? = nil,
    mode: TravelMode? = nil,
    trips: Result<[Trip], Error> = .success([]),
    selectedTrip: Trip? = nil,
    bounds: Bounds? = nil
  ) {
    self.navigateFrom = fromPlace
    self.navigateTo = toPlace
    self.mode = mode ?? Env.current.preferencesController.preferences.preferredTravelMode
    self.trips = trips
    if case .success(let trips) = trips {
      self.selectedTrip = selectedTrip ?? trips.first
    } else {
      assert(self.selectedTrip == nil)
    }
    self.bounds = bounds
  }

  @MainActor
  var isEmpty: Bool {
    if self.navigateFrom == nil && self.navigateTo == nil {
      assert(self.bounds == nil)
      switch self.trips {
      case .success([]):
        break
      default:
        assertionFailure("unexpected trips: \(self.trips)")
      }
      assert(self.selectedTrip == nil)
      return true
    } else {
      return false
    }
  }

  @MainActor
  func clear() {
    self.navigateFrom = nil
    self.navigateTo = nil
    self.bounds = nil
    self.trips = .success([])
    self.selectedTrip = nil
  }
}
