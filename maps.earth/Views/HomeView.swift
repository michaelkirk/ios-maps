//
//  ContentView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import MapLibre
import SwiftUI

private let logger = FileLogger()

func AssertMainThread() {
  assert(Thread.isMainThread)
}

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
  @State var placeDetailsDetent: PresentationDetent = .medium

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
      FrontPageSearch(
        placeholder: "Where to?",
        hasPendingQuery: searchQueue.hasPendingQuery,
        places: $searchQueue.mostRecentResults,
        queryText: $queryText,
        selectedPlace: $selectedPlace,
        tripPlan: tripPlan,
        didDismissSearch: {
          queryText = ""
          searchDetent = minDetentHeight
          dismissKeyboard()
        },
        didSubmitSearch: {
          searchDetent = .medium
          guard let mostRecentlySubmittedQuery = searchQueue.mostRecentlySubmittedQuery else {
            // submitted "search" with empty query, so nothing to do
            return
          }

          guard let mostRecentlyCompletedQuery = searchQueue.mostRecentlyCompletedQuery,
            mostRecentlyCompletedQuery.queryId >= mostRecentlySubmittedQuery.queryId
          else {
            // Wait for query to complete
            self.pendingMapFocus = .pendingSearchResults(mostRecentlySubmittedQuery)
            return
          }

          // query is already ready - zoom to results
          guard let mostRecentResults = searchQueue.mostRecentResults else {
            assertionFailure("mostRecentlySubmittedQuery, but no mostRecentResults")
            return
          }
          self.pendingMapFocus = .searchResults(mostRecentResults)
        },
        placeDetailsDetent: $placeDetailsDetent
      )
      .presentationDetents([.large, .medium, minDetentHeight], selection: $searchDetent)
      .presentationBackgroundInteraction(
        .enabled(upThrough: .medium)
      )
      .presentationDragIndicator(.visible)
      .interactiveDismissDisabled(true)
      .environmentObject(userLocationManager)
      .onChange(of: queryText) { newValue in
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
    }.onChange(of: selectedPlace) { newValue in
      logger.debug(
        "selectedPlace did change -> \(String(describing: newValue))"
      )
      if let newValue = newValue {
        self.pendingMapFocus = .place(newValue)
        self.searchDetent = minDetentHeight
        self.placeDetailsDetent = .medium
      } else if searchQueue.mostRecentResults != nil {
        // return to previous search results
        self.searchDetent = .medium
      }
    }.onChange(of: tripPlan.selectedTrip) { newValue in
      logger.debug(
        "selectedTrip did change -> \(String(describing: newValue))"
      )
      if let newValue = newValue {
        self.pendingMapFocus = .trip(newValue)
        self.placeDetailsDetent = minDetentHeight
      } else {
        self.placeDetailsDetent = .medium
      }
    }.onChange(of: searchQueue.mostRecentResults) { newValue in
      if case .pendingSearchResults(let pendingQuery) = self.pendingMapFocus {
        guard let mostRecentlyCompletedQuery = searchQueue.mostRecentlyCompletedQuery else {
          // no query completed yet
          return
        }
        if mostRecentlyCompletedQuery.queryId >= pendingQuery.queryId {
          guard let mostRecentResults = searchQueue.mostRecentResults else {
            assertionFailure("mostRecentlySubmittedQuery, but no mostRecentResults")
            return
          }
          self.pendingMapFocus = .searchResults(mostRecentResults)
        }
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
  let tripPlan = FixtureData.transitTripPlan
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  return HomeView(
    selectedPlace: tripPlan.navigateTo, tripPlan: tripPlan, searchQueue: searchQueue,
    queryText: "coffee")
}

#Preview("Init") {
  HomeView()
}
