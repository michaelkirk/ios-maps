//
//  TripPlan.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/8/24.
//

import Foundation

// TODO: split this into something like TripQuery and TripResponse
//       since many of these fields will be blank.
class TripPlan: ObservableObject {
  @Published var navigateFrom: Place?
  @Published var navigateTo: Place?
  @Published var mode: TravelMode
  @Published var bounds: Bounds?
  @Published var trips: [Trip]
  @Published var selectedTrip: Trip?
  init(
    from fromPlace: Place? = nil,
    to toPlace: Place? = nil,
    mode: TravelMode = .walk,
    trips: [Trip] = [],
    selectedTrip: Trip? = nil,
    bounds: Bounds? = nil
  ) {
    self.navigateFrom = fromPlace
    self.navigateTo = toPlace
    self.mode = mode
    self.trips = trips
    self.selectedTrip = selectedTrip ?? trips.first
    self.bounds = bounds
  }
}
