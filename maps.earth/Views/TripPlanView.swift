//
//  TripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import MapboxDirections
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

  @State var showSteps: Bool
  @State var showTimePicker: Bool = false
  @State var tripDate: TripDateMode = .departNow

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
      HStack(spacing: 20) {
        // Disable transit for now
        ModeButton(mode: .transit, selectedMode: $tripPlan.mode)
        ModeButton(mode: .car, selectedMode: $tripPlan.mode)
        ModeButton(mode: .bike, selectedMode: $tripPlan.mode)
        ModeButton(mode: .walk, selectedMode: $tripPlan.mode)
      }.onChange(of: tripPlan.mode) { newValue in
        // clear trips for previous mode
        tripPlan.selectedTrip = nil
        tripPlan.trips = .success([])
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

      if tripPlan.mode == .transit {
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

          LabeledCheckbox(isChecked: $tripPlan.transitWithBike) {
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
    }.onChange(of: tripPlan.mode) { newValue in
      queryIfReady()
    }.onChange(of: tripPlan.transitWithBike) { newValue in
      queryIfReady()
    }.onDisappear {
      self.tripPlan.selectedTrip = nil
    }.fullScreenCover(isPresented: showRouteSheet, onDismiss: { tripPlan.selectedRoute = nil }) {
      if case let .success(route) = self.tripPlan.selectedRoute {
        MENavigationViewController(route: route, onDismiss: { tripPlan.selectedRoute = nil })
          // Otherwise Navigation UI stops abruptly above the home button. It is very noticeable in night mode.
          .ignoresSafeArea()
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

struct TripSearchManager {
  struct TripQuery {
    var queryId: UInt64
    var navigateFrom: Place
    var navigateTo: Place
  }

  var tripPlanClient: TripPlanClient {
    Env.current.tripPlanClient
  }

  var distanceMeasurementSystem: Locale.MeasurementSystem {
    // This matches the logic in MapboxDirections.DirectionsOptions.distanceMeasurementSystem
    Locale.autoupdatingCurrent.measurementSystem
  }

  var pendingQueries: [TripQuery] = []
  var completedQueries: [TripQuery] = []

  func query(
    from: Place, to: Place, mode: TravelMode, tripDate: TripDateMode, transitWithBike: Bool
  ) async throws
    -> Result<[Trip], TripPlanError>
  {
    let measurementSystem: MeasurementSystem
    if self.distanceMeasurementSystem == .metric {
      measurementSystem = .metric
    } else {
      measurementSystem = .imperial
    }

    var modes = [mode]
    if mode == .transit && transitWithBike {
      modes.append(.bike)
    }

    return try await tripPlanClient.query(
      from: from, to: to, modes: modes, measurementSystem: measurementSystem, tripDate: tripDate)
  }
}

struct TripPlanSheetContents: View {
  @ObservedObject var tripPlan: TripPlan
  @State var showSteps: Bool = false

  var body: some View {
    SheetContents(
      title: "Directions", onClose: { tripPlan.clear() }, currentDetent: .constant(.medium)
    ) {
      GeometryReader { geometry in
        ScrollView {
          TripPlanView(tripPlan: tripPlan, showSteps: showSteps)
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
    TripPlanSheetContents(tripPlan: tripPlan)
  }
}

#Preview("Transit Trips") {
  let tripPlan = FixtureData.transitTripPlan
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
