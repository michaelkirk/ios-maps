//
//  TripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import SwiftUI

struct TripPlanView: View {
  @ObservedObject var tripPlan: TripPlan
  var getFocus: () -> LngLat?
  var searcher = TripSearchManager()

  var body: some View {
    VStack(alignment: .leading) {
      VStack {
        PlaceField(header: "From", place: $tripPlan.navigateFrom, getFocus: getFocus)
        Divider()
        PlaceField(header: "To", place: $tripPlan.navigateTo, getFocus: getFocus)
      }.background(Color.hw_lightGray)
        .cornerRadius(8)

      List(tripPlan.trips, selection: $tripPlan.selectedTrip) { trip in
        Button(action: {
          print("selecting \(trip)")
          tripPlan.selectedTrip = trip
        }) {
          HStack {
            VStack(alignment: .leading) {
              Text(trip.durationFormatted).font(.headline).dynamicTypeSize(.xxxLarge)
              Text(trip.distanceFormatted).font(.subheadline).contrast(50)
            }
            Spacer()
            Button("Details") {
              print("TODO: handle \"GO\" (detail view) \(trip)")
              tripPlan.selectedTrip = trip
            }.fontWeight(.medium)
              .foregroundColor(.white)
              .padding()
              .background(.green)
              .cornerRadius(8)
              .hidden()  // TODO: handle detail view
          }
        }.background(trip == tripPlan.selectedTrip ? .blue : .clear)
      }.listStyle(.plain)
        .cornerRadius(8)
    }.onChange(of: tripPlan.navigateFrom) { oldValue, newValue in
      queryIfReady()
    }.onChange(of: tripPlan.navigateTo) { oldValue, newValue in
      queryIfReady()
    }
  }
  func queryIfReady() {
    guard let from = tripPlan.navigateFrom else {
      return
    }
    guard let to = tripPlan.navigateTo else {
      return
    }

    // TODO: track request_id, discard stale results
    Task {
      guard let trips = try await searcher.query(from: from, to: to) else {
        // better handling of nil?
        return
      }
      await MainActor.run {
        print("new trips: \(trips.map { $0.durationFormatted })")
        self.tripPlan.trips = trips
        // is this working?
        self.tripPlan.selectedTrip = trips.first
      }
    }
  }
}

struct TripSearchManager {
  struct TripQuery {
    var queryId: UInt64
    var navigateFrom: Place
    var navigateTo: Place
  }

  var pendingQueries: [TripQuery] = []
  var completedQueries: [TripQuery] = []

  func query(from: Place, to: Place) async throws -> [Trip]? {
    // TODO: pass through mode and units
    try await TripPlanClient().query(
      from: from.location, to: to.location, mode: .bike, units: .miles)
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
