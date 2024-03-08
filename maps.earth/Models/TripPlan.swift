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
  @Published var bounds: Bounds?
  @Published var trips: [Trip]
  @Published var selectedTrip: Trip?
  init(
    from fromPlace: Place? = nil, to toPlace: Place? = nil, trips: [Trip] = [],
    bounds: Bounds? = nil,
    selectedTrip: Trip? = nil
  ) {
    self.navigateFrom = fromPlace
    self.navigateTo = toPlace
    self.trips = trips
    self.selectedTrip = selectedTrip ?? trips.first
  }
}
