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
  @State var placeDetailsDetent: PresentationDetent = minDetentHeight

  @State var userLocationState: UserLocationState = .initial
  @StateObject var userLocationManager = UserLocationManager()
  // start by zooming to the user's current location if we have it
  @State var pendingMapFocus: MapFocus? = .userLocation {
    didSet {
      print(
        "pendingMapFocus: \(String(describing: oldValue)) -> \(String(describing: pendingMapFocus))"
      )
    }
  }

  var body: some View {
    MapView(
      searchResults: $searchQueue.mostRecentResults, selectedPlace: $selectedPlace,
      userLocationState: $userLocationState,
      mostRecentUserLocation: $userLocationManager.mostRecentUserLocation,
      pendingMapFocus: $pendingMapFocus,
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
        },
        placeDetailsDetent: $placeDetailsDetent
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
    }.onChange(of: selectedPlace) { oldValue, newValue in
      logger.debug(
        "selectedPlace did change: \(String(describing: oldValue)) -> \(String(describing: newValue))"
      )
      if let newValue = newValue {
        self.pendingMapFocus = .place(newValue)
        self.searchDetent = minDetentHeight
        self.placeDetailsDetent = .medium
      } else if let mostRecentResults = searchQueue.mostRecentResults {
        // return to previous search results
        self.pendingMapFocus = .searchResults(mostRecentResults)
        self.searchDetent = .medium
      }
    }.onChange(of: tripPlan.selectedTrip) { oldValue, newValue in
      logger.debug(
        "selectedTrip did change: \(String(describing: oldValue)) -> \(String(describing: newValue))"
      )
      if let newValue = newValue {
        self.pendingMapFocus = .trip(newValue)
        self.placeDetailsDetent = minDetentHeight
      } else {
        self.placeDetailsDetent = .medium
      }
    }.onChange(of: searchQueue.mostRecentResults) { oldValue, newValue in
      logger.debug(
        "searchResults did change: \(String(describing: oldValue)) -> \(String(describing: newValue))"
      )
      if let newValue = newValue {
        self.pendingMapFocus = .searchResults(newValue)
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
