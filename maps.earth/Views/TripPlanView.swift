//
//  TripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import SwiftUI

struct TripPlanView: View {
  @StateObject var tripPlan: TripPlan
  var getFocus: () -> LngLat?

  init(to place: Place? = nil, getFocus: @escaping () -> LngLat?) {
    let tripPlan = TripPlan(to: place)
    self.init(tripPlan: tripPlan, getFocus: getFocus)
  }

  init(tripPlan: TripPlan, getFocus: @escaping () -> LngLat?) {
    self._tripPlan = StateObject(wrappedValue: tripPlan)
    self.getFocus = getFocus
  }

  var body: some View {
    VStack(alignment: .leading) {
      PlaceField(header: "From", place: $tripPlan.navigateFrom, getFocus: getFocus)
      Divider()
      PlaceField(header: "To", place: $tripPlan.navigateTo, getFocus: getFocus)
      Divider()
      List(tripPlan.trips, selection: $tripPlan.selectedTrip) { trip in
        HStack {
          VStack(alignment: .leading) {
            Text(trip.durationFormatted).font(.headline).dynamicTypeSize(.xxxLarge)
            Text(trip.distanceFormatted).font(.subheadline).contrast(50)
          }
          Spacer()
          Button("GO") {
            print("go (selecting) \(trip)")
            tripPlan.selectedTrip = trip
          }.fontWeight(.medium)
            .foregroundColor(.white)
            .padding()
            .background(.green)
            .cornerRadius(10)
        }.onTapGesture {
          print("selecting \(trip)")
          tripPlan.selectedTrip = trip
        }
      }
    }
  }
}

func fakeFocus() -> LngLat? {
  LngLat(lng: -122.754113, lat: 47.079458)
}

#Preview("Showing trips") {
  let tripPlan = TripPlan(
    from: FixtureData.places[0], to: FixtureData.places[1], trips: FixtureData.bikeTrips)
  return TripPlanView(tripPlan: tripPlan, getFocus: fakeFocus)
}

#Preview("Only 'to' selected") {
  let tripPlan = TripPlan(to: FixtureData.places[1])
  return TripPlanView(tripPlan: tripPlan, getFocus: fakeFocus)
}

#Preview("Only 'from' selected") {
  let tripPlan = TripPlan(from: FixtureData.places[0])
  return TripPlanView(tripPlan: tripPlan, getFocus: fakeFocus)
}
