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
  var searcher = TripSearchManager()

  @Binding var showSteps: Bool

  var body: some View {
    VStack(alignment: .leading) {
      HStack(spacing: 20) {
        // Disable transit for now
        // ModeButton(mode: .transit, selectedMode: $tripPlan.mode)
        ModeButton(mode: .car, selectedMode: $tripPlan.mode)
        ModeButton(mode: .bike, selectedMode: $tripPlan.mode)
        ModeButton(mode: .walk, selectedMode: $tripPlan.mode)
      }
      .padding(.bottom, 8)

      VStack {
        PlaceField(header: "From", place: $tripPlan.navigateFrom)
        Divider().padding(.bottom, 4)
        PlaceField(header: "To", place: $tripPlan.navigateTo)
      }
      .padding(.top, 10)
      .padding(.bottom, 10)
      .background(Color.hw_lightGray)
      .cornerRadius(8)

      List(tripPlan.trips, selection: $tripPlan.selectedTrip) { trip in
        VStack(alignment: .leading) {
          Button(action: {
            if tripPlan.selectedTrip == trip {
              showSteps = true
            } else {
              tripPlan.selectedTrip = trip
            }
          }) {
            HStack(spacing: 8) {
              Spacer().frame(maxWidth: 8, maxHeight: .infinity)
                .background(trip == tripPlan.selectedTrip ? .blue : .clear)
              VStack(alignment: .leading) {
                Text(trip.durationFormatted).font(.headline).dynamicTypeSize(.xxxLarge)
                Text(trip.distanceFormatted).font(.subheadline)  //.foregroundColor(.hw_secondaryTextColor)
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
            }.frame(minHeight: 70)
          }
        }.listRowInsets(EdgeInsets())
      }.listStyle(.plain)
        .sheet(isPresented: $showSteps) {
          ManeuverListSheetContents(trip: tripPlan.selectedTrip!, onClose: { showSteps = false })
        }
        .cornerRadius(8)
    }.onAppear {
      queryIfReady()
    }.onChange(of: tripPlan.navigateFrom) { oldValue, newValue in
      queryIfReady()
    }.onChange(of: tripPlan.navigateTo) { oldValue, newValue in
      queryIfReady()
    }.onChange(of: tripPlan.mode) { oldValue, newValue in
      queryIfReady()
    }.onDisappear {
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
      do {
        guard let trips = try await searcher.query(from: from, to: to, mode: tripPlan.mode) else {
          // better handling of nil?
          print("no trips found")
          return
        }
        await MainActor.run {
          self.tripPlan.trips = trips
          self.tripPlan.selectedTrip = trips.first
        }

      } catch {
        print("error in query: \(error)")
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
    // TODO: pass units through Env?
    let units: DistanceUnit
    if Locale.current.measurementSystem == .metric {
      units = .kilometers
    } else {
      units = .miles
    }
    return try await TripPlanClient().query(
      from: from, to: to, mode: mode, units: units)
  }
}

struct TripPlanSheetContents: View {
  @ObservedObject var tripPlan: TripPlan
  @State var showSteps: Bool = false

  var body: some View {
    SheetContents(title: "Directions", onClose: { tripPlan.clear() }) {
      ScrollView {
        TripPlanView(tripPlan: tripPlan, showSteps: $showSteps)
          .containerRelativeFrame(.vertical)
          .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
      }
    }
  }
}

#Preview("Trips") {
  let tripPlan = FixtureData.tripPlan
  return Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan)
  }
}

#Preview("Steps") {
  let tripPlan = FixtureData.tripPlan
  return Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan, showSteps: true)
  }
}

#Preview("Only 'to' selected") {
  let tripPlan = TripPlan(to: FixtureData.places[.zeitgeist])
  return Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan)
  }
}

#Preview("Only 'from' selected") {
  let tripPlan = TripPlan(from: FixtureData.places[.dubsea])
  return Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan)
  }
}
