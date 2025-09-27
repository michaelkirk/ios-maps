//
//  TripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import CoreLocation
import Foundation
import MapboxDirections
import SwiftUI

struct ModePicker: View {
  @Binding var selectedMode: TravelMode

  var body: some View {
    HStack(spacing: 20) {
      ModeButton(mode: .transit, selectedMode: $selectedMode)
      ModeButton(mode: .car, selectedMode: $selectedMode)
      ModeButton(mode: .bike, selectedMode: $selectedMode)
      ModeButton(mode: .walk, selectedMode: $selectedMode)
    }
  }
}

struct OriginDestinationFieldSet: View {
  @Binding var navigateFrom: Place?
  @Binding var navigateTo: Place?
  var body: some View {
    VStack {
      PlaceField(header: "From", place: $navigateFrom)
      Divider().padding(.bottom, 4)
      PlaceField(header: "To", place: $navigateTo)
    }
    .padding(.top, 10)
    .padding(.bottom, 10)
    .background(Color.hw_lightGray)
    .cornerRadius(8)
  }
}

struct TransitFilters: View {
  @State var showTimePicker: Bool = false
  @Binding var tripDate: TripDateMode
  @Binding var transitWithBike: Bool

  var body: some View {
    HStack(spacing: 16) {
      Button(action: { showTimePicker = true }) {
        switch tripDate {
        case .departNow:
          Text("Leave now")
        case .departAt(let date):
          Text("Leave at \(formatRelativeDate(date))")
        case .arriveBy(let date):
          Text("Arrive by \(formatRelativeDate(date))")
        }
        Image(systemName: "chevron.down").imageScale(.small)
          .padding(.top, 3)
      }
      .foregroundColor(.black)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .roundedBorder(.black, cornerRadius: 8)
      .sheet(isPresented: $showTimePicker) {
        SheetContentsWithoutTitle(currentDetent: .constant(.medium)) {
          VStack {
            TripDatePicker(mode: $tripDate)
            HStack(spacing: 60) {
              Button(
                "Cancel",
                action: {
                  // maybe we should restore to previous value rather than always reset to now
                  tripDate = .departNow
                  showTimePicker = false
                }
              ).foregroundColor(.black)
              Button("Done", action: { showTimePicker = false })
            }.font(.title3)
          }.padding()
        }
      }

      LabeledCheckbox(isChecked: $transitWithBike) {
        HStack(spacing: 2) {
          Text("🚲").padding(.top, -6)  // bike baseline is super low for some reason
          Text("Bring a bike")
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .roundedBorder(.black, cornerRadius: 8)
    }
  }
}

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
    .background(mode == selectedMode ? Color.hw_blue : .hw_lightGray)
    .cornerRadius(3.0)
  }
}

var searcher = TripSearchManager()

struct TripPlanView: View {
  @ObservedObject var tripPlan: TripPlan
  @State var travelMode: TravelMode

  @State var showSteps: Bool
  @State var tripDate: TripDateMode = .departNow
  @EnvironmentObject var preferences: Preferences
  var didCompleteTrip: () -> Void

  var body: some View {
    let showRouteSheet = Binding(
      get: {
        if case .success(_) = $tripPlan.selectedRoute.wrappedValue {
          return true
        } else {
          return false
        }
      },
      set: { newValue in
        print("new value for showRouteSheet: \(newValue)")
      }
    )

    return VStack(alignment: .leading) {
      ModePicker(selectedMode: $travelMode).onChange(of: travelMode) { newValue in
        // clear trips for previous mode
        tripPlan.selectedTrip = nil
        tripPlan.trips = .success([])
        Task { await preferences.setPreferredTravelMode(newValue) }
      }

      OriginDestinationFieldSet(
        navigateFrom: $tripPlan.navigateFrom, navigateTo: $tripPlan.navigateTo)

      if tripPlan.mode == .transit {
        TransitFilters(tripDate: $tripDate, transitWithBike: $tripPlan.transitWithBike)
      }

      switch tripPlan.trips {
      case .failure(let error):
        switch error {
        case let tripPlanError as TripPlanError:
          Text(tripPlanError.localizedDescription)
        case let decodingError as DecodingError:
          let _ = print("Decoding error while fetching trip plan: \(decodingError)")
          Text("Unable to get directions - there was a problem with the servers response.")
        default:
          Text("Unable to get directions — \(error.localizedDescription)")
        }
      case .success(let trips):
        TripList(tripPlan: tripPlan, trips: .constant(trips), showSteps: $showSteps)
      }
    }.onAppear {
      // don't blow away mocked values in Preview
      if !Env.current.isMock {
        queryIfReady()
      }
    }.onChange(of: tripPlan.navigateFrom) { newValue in
      queryIfReady()
    }.onChange(of: tripPlan.navigateTo) { newValue in
      queryIfReady()
    }.onChange(of: tripDate) { newValue in
      queryIfReady()
    }.onChange(of: travelMode) { newValue in
      queryIfReady()
    }.onChange(of: tripPlan.transitWithBike) { newValue in
      queryIfReady()
    }.onDisappear {
      self.tripPlan.selectedTrip = nil
    }.fullScreenCover(isPresented: showRouteSheet, onDismiss: { tripPlan.selectedRoute = nil }) {
      if case .success(let route) = self.tripPlan.selectedRoute {
        MENavigationView(
          route: route,
          travelMode: tripPlan.mode,
          measurementSystem: searcher.measurementSystem,
          stopNavigation: { didComplete in
            tripPlan.selectedRoute = nil
            if didComplete {
              self.tripPlan.selectedTrip = nil
              self.tripPlan.navigateTo = nil
              self.tripPlan.navigateFrom = nil
              self.didCompleteTrip()
            }
          }
        )
      } else {
        let _ = assertionFailure("showing route sheet without a successful route.")
      }
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
        let trips = try await searcher.query(
          from: from, to: to, mode: tripPlan.mode, tripDate: tripDate,
          transitWithBike: tripPlan.transitWithBike)

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

typealias QueryID = UInt64
struct TripSearchManager {

  @MainActor
  var tripPlanClient: TripPlanClient {
    Env.current.tripPlanClient
  }

  var measurementSystem: MapboxDirections.MeasurementSystem {
    // This matches the logic in MapboxDirections.DirectionsOptions.distanceMeasurementSystem
    if Locale.autoupdatingCurrent.measurementSystem == .metric {
      .metric
    } else {
      .imperial
    }
  }

  var mostRecentlyCompletedQuery: (id: QueryID, trips: [Trip])? = nil
  var nextQueryID: QueryID = 1

  mutating func query(
    from: Place, to: Place, mode: TravelMode, tripDate: TripDateMode, transitWithBike: Bool
  ) async throws
    -> Result<[Trip], TripPlanError>
  {
    var modes = [mode]
    if mode == .transit && transitWithBike {
      modes.append(.bike)
    }
    let queryID = nextQueryID
    nextQueryID += 1
    let result = try await tripPlanClient.query(
      from: from, to: to, modes: modes, measurementSystem: measurementSystem, tripDate: tripDate)

    guard case .success(var trips) = result else {
      return result
    }

    guard mostRecentlyCompletedQuery?.id ?? 0 < queryID else {
      // slower request just now finished, return more recent results instead
      print("slower request just now finished, return more recent results instead")
      return .success(mostRecentlyCompletedQuery!.trips)
    }

    guard [TravelMode.bike, TravelMode.walk].contains(mode) else {
      return result
    }

    for (idx, var trip) in trips.enumerated() {
      let geometry = trip.raw.legs[0].geometry
      guard let elevation = try? await fetchElevation(polyline: geometry) else {
        continue
      }
      trip.setElevationProfile(elevation)
      trips[idx] = trip
    }
    self.mostRecentlyCompletedQuery = (id: queryID, trips: trips)
    return .success(trips)
  }

  func fetchElevation(polyline: String) async throws -> ElevationProfile {
    try await tripPlanClient.elevation(polyline: polyline).get()
  }
}

struct TripPlanSheetContents: View {
  @ObservedObject var tripPlan: TripPlan
  @State var showSteps: Bool = false
  var didCompleteTrip: () -> Void

  var body: some View {
    SheetContents(
      title: "Directions", onClose: { tripPlan.clear() }, currentDetent: .constant(.medium)
    ) {
      GeometryReader { geometry in
        ScrollView {
          TripPlanView(
            tripPlan: tripPlan, travelMode: tripPlan.mode, showSteps: showSteps,
            didCompleteTrip: didCompleteTrip
          )
          .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
          .frame(minHeight: geometry.size.height)
        }
      }
    }
  }
}

#Preview("Walk Trips") {
  let tripPlan = FixtureData.walkTripPlan
  return Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan, didCompleteTrip: {})
  }
  .environmentObject(Preferences.forTesting())
}

#Preview("Transit Trips") {
  let tripPlan = FixtureData.transitTripPlan
  return Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan, didCompleteTrip: {})
  }
  .environmentObject(Preferences.forTesting())
}

#Preview("TripPlan error") {
  Env.current = Env(offlineWithMockData: ())
  let tripPlan = FixtureData.tripPlan
  tripPlan.trips = .failure(FixtureData.bikeTripError)
  return Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan, didCompleteTrip: {})
  }
  .environmentObject(Preferences.forTesting())
}

#Preview("Steps") {
  let tripPlan = FixtureData.tripPlan
  return Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan, showSteps: true, didCompleteTrip: {})
  }
  .environmentObject(Preferences.forTesting())
}

#Preview("Only 'to' selected") {
  let tripPlan = TripPlan(to: FixtureData.places[.zeitgeist])
  Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan, didCompleteTrip: {})
  }
  .environmentObject(Preferences.forTesting())
}

#Preview("Only 'from' selected") {
  let tripPlan = TripPlan(from: FixtureData.places[.dubsea])
  Text("").sheet(isPresented: .constant(true)) {
    TripPlanSheetContents(tripPlan: tripPlan, didCompleteTrip: {})
  }
  .environmentObject(Preferences.forTesting())
}
