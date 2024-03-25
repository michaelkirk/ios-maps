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

      VStack {
        PlaceField(header: "From", place: $tripPlan.navigateFrom)
        Divider().padding(.bottom, 4)
        PlaceField(header: "To", place: $tripPlan.navigateTo)
      }
      .padding(.top, 10)
      .padding(.bottom, 10)
      .background(Color.hw_lightGray)
      .cornerRadius(8)

      ScrollViewReader { scrollView in
        switch tripPlan.trips {
        case .failure(let error):
          switch error {
          case let tripPlanError as TripPlanError:
            Text(tripPlanError.localizedDescription)
          default:
            Text("Unable to get directions — \(error.localizedDescription)")
          }
        case .success(let trips):
          List(trips, selection: $tripPlan.selectedTrip) { trip in
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
                    Text(trip.distanceFormatted).font(.subheadline).foregroundColor(.secondary)
                  }.padding(.top, 8).padding(.bottom, 8)
                  Spacer()
                  Button("Steps") {
                    tripPlan.selectedTrip = trip
                    showSteps = true
                  }.fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.green)
                    .cornerRadius(8)
                    .scenePadding(.trailing)
                }
              }
            }.listRowInsets(EdgeInsets())
          }.listStyle(.plain)
            .onChange(of: tripPlan.selectedTrip) { newValue in
              guard let newValue = newValue else {
                return
              }
              withAnimation {
                scrollView.scrollTo(newValue.id, anchor: .top)
              }
            }
        }
      }.sheet(isPresented: $showSteps) {
        ManeuverListSheetContents(trip: tripPlan.selectedTrip!, onClose: { showSteps = false })
      }
      .cornerRadius(8)
      .frame(minHeight: 200)
    }.onAppear {
      // don't blow away mocked values in Preview
      if !Env.current.isMock {
        queryIfReady()
      }
    }.onChange(of: tripPlan.navigateFrom) { newValue in
      queryIfReady()
    }.onChange(of: tripPlan.navigateTo) { newValue in
      queryIfReady()
    }.onChange(of: tripPlan.mode) { newValue in
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
        let trips = try await searcher.query(from: from, to: to, mode: tripPlan.mode)
        await MainActor.run {
          self.tripPlan.trips = trips.mapError { $0 as any Error }
          if case .success(let trips) = trips {
            self.tripPlan.selectedTrip = trips.first
          }
        }
      } catch {
        await MainActor.run {
          print("error in query: \(error)")
          self.tripPlan.trips = .failure(error)
          self.tripPlan.selectedTrip = nil
        }
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

  var tripPlanClient: TripPlanClient {
    Env.current.tripPlanClient
  }

  var pendingQueries: [TripQuery] = []
  var completedQueries: [TripQuery] = []

  func query(from: Place, to: Place, mode: TravelMode) async throws -> Result<[Trip], TripPlanError>
  {
    // TODO: pass units through Env?
    let units: DistanceUnit
    if Locale.current.measurementSystem == .metric {
      units = .kilometers
    } else {
      units = .miles
    }
    return try await tripPlanClient.query(
      from: from, to: to, mode: mode, units: units)
  }
}

struct TripPlanSheetContents: View {
  @ObservedObject var tripPlan: TripPlan
  @State var showSteps: Bool = false

  var body: some View {
    SheetContents(
      title: "Directions", onClose: { tripPlan.clear() }, currentDetent: .constant(.medium)
    ) {
      ScrollView {
        TripPlanView(tripPlan: tripPlan, showSteps: $showSteps)
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

#Preview("TripPlan error") {
  Env.current = Env(offlineWithMockData: ())
  let tripPlan = FixtureData.tripPlan
  tripPlan.trips = .failure(FixtureData.bikeTripError)
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
