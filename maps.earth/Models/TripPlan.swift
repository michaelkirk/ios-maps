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
class TripPlan: ObservableObject {
  @Published var navigateFrom: Place?
  @Published var navigateTo: Place?
  @Published var mode: TravelMode {
    didSet {
      Env.current.preferencesController.setPreferredTravelMode(mode)
    }
  }
  @Published var transitWithBike: Bool = false
  @Published var bounds: Bounds?
  @Published var trips: Result<[Trip], Error>
  @Published var selectedTrip: Trip?
  @Published var selectedRoute: Result<Route, Error>?

  init(
    from fromPlace: Place? = nil,
    to toPlace: Place? = nil,
    mode: TravelMode = Env.current.preferencesController.preferences.preferredTravelMode,
    trips: Result<[Trip], Error> = .success([]),
    selectedTrip: Trip? = nil,
    bounds: Bounds? = nil
  ) {
    self.navigateFrom = fromPlace
    self.navigateTo = toPlace
    self.mode = mode
    self.trips = trips
    if case .success(let trips) = trips {
      self.selectedTrip = selectedTrip ?? trips.first
    } else {
      assert(self.selectedTrip == nil)
    }
    self.bounds = bounds
  }

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

  func clear() {
    self.navigateFrom = nil
    self.navigateTo = nil
    self.bounds = nil
    self.trips = .success([])
    self.selectedTrip = nil
  }
}
