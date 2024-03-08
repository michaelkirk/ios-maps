//
//  TripPlan.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/8/24.
//

import Foundation

class TripPlan: ObservableObject {
  @Published var navigateFrom: Place?
  @Published var navigateTo: Place?
  @Published var trips: [Trip]
  @Published var selectedTrip: Trip?
  init(
    from fromPlace: Place? = nil, to toPlace: Place? = nil, trips: [Trip] = [],
    selectedTrip: Trip? = nil
  ) {
    self.navigateFrom = fromPlace
    self.navigateTo = toPlace
    self.trips = trips
    self.selectedTrip = selectedTrip ?? trips.first
  }
}
