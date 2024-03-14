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

  @State var mapView: MLNMapView?

  @StateObject var searchQueue: SearchQueue = SearchQueue()
  @State var queryText: String = ""
  @State var searchDetent: PresentationDetent = minDetentHeight
  @State var userLocationState: UserLocationState = .initial
  @StateObject var userLocationManager = UserLocationManager()

  var presentedSheet: PresentedSheet = .search

  var body: some View {
    MapView(
      places: $searchQueue.mostRecentResults, selectedPlace: $selectedPlace, mapView: $mapView,
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
      .environmentObject(userLocationManager)
      .onChange(of: queryText) { oldValue, newValue in
        let focus = (self.mapView?.centerCoordinate).map { LngLat(coord: $0) }
        searchQueue.textDidChange(newValue: newValue, focus: focus)
      }
      .scenePadding(.top)
      .presentationDetents([.large, .medium, minDetentHeight], selection: $searchDetent)
      .presentationBackgroundInteraction(
        .enabled(upThrough: .medium)
      )
      .interactiveDismissDisabled(true)
      .edgesIgnoringSafeArea(.all)
      .background(Color.hw_sheetBackground)
      .onAppear {
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
}

enum PresentedSheet {
  case search
  case placeDetail(Binding<Place>)
}

#Preview("search results") {
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  let result = HomeView(searchQueue: searchQueue, queryText: "coffee")
  //  result.searchQueue.mostRecentResults = FixtureData.places.all
  result.searchDetent = .large
  return result
}

#Preview("show detail") {
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  let result = HomeView(
    selectedPlace: FixtureData.places[.santaLucia], searchQueue: searchQueue, queryText: "coffee")
  return result
}

#Preview("Initial") {
  HomeView()
}
//
//#Preview("with directions") {
//  let tripPlan = FixtureData.tripPlan
//  return ContentView(
//    selectedPlace: tripPlan.navigateTo,
//    tripPlan: tripPlan,
//    toSearchQueue: LegacySearchQueue(
//      searchText: "coffee", mostRecentResults: FixtureData.places.all)
//  )
//}
