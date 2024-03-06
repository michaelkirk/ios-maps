//
//  TripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import SwiftUI

struct TripPlanner: View {
  @State var navigateFrom: Place?
  @State var navigateTo: Place?
  @State var trips: [Trip] = []
  @State var selectedTrip: Trip?

  var getFocus: () -> LngLat?

  var body: some View {
    VStack(alignment: .leading) {
      PlaceField(header: "From", place: $navigateFrom, getFocus: getFocus)
      Divider()
      PlaceField(header: "To", place: $navigateTo, getFocus: getFocus)
      Divider()
      List(trips, selection: $selectedTrip) { trip in
        HStack {
          VStack(alignment: .leading) {
            Text(trip.durationFormatted).font(.headline).dynamicTypeSize(.xxxLarge)
            Text(trip.distanceFormatted).font(.subheadline).contrast(50)
          }
          Spacer()
          Button("GO") {
            print("go (selecting) \(trip)")
            selectedTrip = trip
          }.fontWeight(.medium)
           .foregroundColor(.white)
           .padding()
           .background(.green)
           .cornerRadius(10)
        }.onTapGesture {
          print("selecting \(trip)")
          selectedTrip = trip
        }
      }
    }
  }
}

func fakeFocus() -> LngLat? {
  LngLat(lng: -122.754113, lat: 47.079458)
}

#Preview("Only 'to' selected") {
  TripPlanner(navigateTo: FixtureData.places[0], getFocus: fakeFocus)
}

#Preview("Only 'from' selected") {
  TripPlanner(navigateFrom: FixtureData.places[0], getFocus: fakeFocus)
}

#Preview("Showing trips") {
  TripPlanner(navigateFrom: FixtureData.places[0], navigateTo: FixtureData.places[1], trips: FixtureData.bikeTrips, getFocus: fakeFocus)
}
