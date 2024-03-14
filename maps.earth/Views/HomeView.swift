//
//  ContentView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import MapLibre
import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier!,
  category: String(describing: #file)
)

class UserLocationManager: ObservableObject {
  var mostRecentUserLocation: CLLocation?
}

let minDetentHeight = PresentationDetent.height(68)
struct HomeView: View {
  @State var selectedPlace: Place?
  @StateObject var tripPlan: TripPlan = TripPlan()

  @StateObject var searchQueue: SearchQueue = SearchQueue()
  @State var queryText: String = ""
  @State var searchDetent: PresentationDetent = minDetentHeight
  @State var userLocationState: UserLocationState = .initial
  @StateObject var userLocationManager = UserLocationManager()

  var body: some View {
    MapView(
      places: $searchQueue.mostRecentResults, selectedPlace: $selectedPlace,
      userLocationState: $userLocationState,
      mostRecentUserLocation: $userLocationManager.mostRecentUserLocation,
      tripPlan: tripPlan
    )
    .edgesIgnoringSafeArea(.all)
    .sheet(isPresented: .constant(true)) {
      FrontPagePlaceSearch(
        placeholder: "Where to?",
        hasPendingQuery: searchQueue.hasPendingQuery,
        places: $searchQueue.mostRecentResults,
        queryText: $queryText,
        selectedPlace: $selectedPlace,
        tripPlan: tripPlan,
        didDismissSearch: {
          queryText = ""
          searchDetent = minDetentHeight
        }
      )
      .scenePadding(.top)
      .ignoresSafeArea(.container)  // don't trim results at bottom of notched devices
      .background(Color.hw_sheetBackground)
      .presentationDetents([.large, .medium, minDetentHeight], selection: $searchDetent)
      .presentationBackgroundInteraction(
        .enabled(upThrough: .medium)
      )
      .presentationDragIndicator(.visible)
      .interactiveDismissDisabled(true)
      .environmentObject(userLocationManager)
      .onChange(of: queryText) { oldValue, newValue in
        searchQueue.textDidChange(newValue: newValue)
      }
    }.onAppear {
      switch CLLocationManager().authorizationStatus {
      case .notDetermined:
        break
      case .denied, .restricted:
        self.userLocationState = .denied
      case .authorizedAlways, .authorizedWhenInUse:
        self.userLocationState = .showing
      @unknown default:
        break
      }
    }
  }
}

#Preview("Search") {
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  return HomeView(searchQueue: searchQueue, queryText: "coffee", searchDetent: .large)
}

#Preview("Place") {
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  return HomeView(
    selectedPlace: FixtureData.places[.santaLucia], searchQueue: searchQueue, queryText: "coffee")
}

#Preview("Trip") {
  let tripPlan = FixtureData.tripPlan
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  return HomeView(
    selectedPlace: tripPlan.navigateFrom, tripPlan: tripPlan, searchQueue: searchQueue,
    queryText: "coffee")
}

#Preview("Init") {
  HomeView()
}
