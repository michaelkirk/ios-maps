//
//  TripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import SwiftUI

struct ModeButton: View {
  let mode: TravelMode
  @Binding var selectedMode: TravelMode
  var body: some View {
    Button(action: { selectedMode = mode }) {
      let modeText =
        switch mode {
        case .walk: "Walk"
        case .bike: "Bike"
        case .transit: "Transit"
        case .car: "Drive"
        }
      Text(modeText)
    }
    .foregroundColor(mode == selectedMode ? .white : .hw_darkGray)
    .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    .background(mode == selectedMode ? .blue : .hw_lightGray)
    .cornerRadius(3.0)
  }
}

struct TripPlanView: View {
  @ObservedObject var tripPlan: TripPlan
  var getFocus: () -> LngLat?
  var searcher = TripSearchManager()

  var body: some View {
    VStack(alignment: .leading) {
      HStack(spacing: 20) {
        ModeButton(mode: .transit, selectedMode: $tripPlan.mode)
        ModeButton(mode: .car, selectedMode: $tripPlan.mode)
        ModeButton(mode: .bike, selectedMode: $tripPlan.mode)
        ModeButton(mode: .walk, selectedMode: $tripPlan.mode)
      }
      .scenePadding(.bottom)
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
          HStack(spacing: 8) {
            Spacer().frame(maxWidth: 8, maxHeight: .infinity)
              .background(trip == tripPlan.selectedTrip ? .blue : .clear)
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
        }
        .listRowInsets(EdgeInsets())
      }.listStyle(.plain)
        .cornerRadius(8)
    }.onChange(of: tripPlan.navigateFrom) { oldValue, newValue in
      queryIfReady()
    }.onChange(of: tripPlan.navigateTo) { oldValue, newValue in
      queryIfReady()
    }.onChange(of: tripPlan.mode) { oldValue, newValue in
      queryIfReady()
    }.onDisappear {
      print(">>> disappeared")
      self.tripPlan.selectedTrip = nil
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
      guard let trips = try await searcher.query(from: from, to: to, mode: tripPlan.mode) else {
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

  func query(from: Place, to: Place, mode: TravelMode) async throws -> [Trip]? {
    // TODO: pass through units
    try await TripPlanClient().query(
      from: from, to: to, mode: mode, units: .miles)
  }
}

func fakeFocus() -> LngLat? {
  LngLat(lng: -122.754113, lat: 47.079458)
}

#Preview("Showing trips") {
  let tripPlan = FixtureData.tripPlan
  return TripPlanView(tripPlan: tripPlan, getFocus: fakeFocus)
}

#Preview("Only 'to' selected") {
  let tripPlan = TripPlan(to: FixtureData.places[.zeitgeist])
  return TripPlanView(tripPlan: tripPlan, getFocus: fakeFocus)
}

#Preview("Only 'from' selected") {
  let tripPlan = TripPlan(from: FixtureData.places[.dubsea])
  return TripPlanView(tripPlan: tripPlan, getFocus: fakeFocus)
}
