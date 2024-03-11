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

let minDetentHeight = PresentationDetent.height(72)
struct ContentView: View {
  @State var selectedPlace: Place?
  @StateObject var tripPlan: TripPlan = TripPlan()

  @State var mapView: MLNMapView?

  @StateObject var searchQueue: SearchQueue = SearchQueue()
  @State var queryText: String = ""
  @State var searchDetent: PresentationDetent = minDetentHeight

  @State var isShowingSearchSheet = true
  @State var isShowingDetailSheet = false

  var presentedSheet: PresentedSheet = .search

  var body: some View {
    MapView(
      places: $searchQueue.mostRecentResults, selectedPlace: $selectedPlace, mapView: $mapView,
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
        tripPlan: tripPlan
      )
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
    }.onChange(of: selectedPlace) { oldValue, newValue in
      if newValue == nil {
        //        isShowingSearchSheet = true
        //        isShowingDetailSheet = false
        //        searchDetent = .medium
      } else if oldValue == nil {
        // Just selected a value for the first time

        //        isShowingSearchSheet = false
        //        isShowingDetailSheet = true
        searchDetent = .medium
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
  let result = ContentView(searchQueue: searchQueue, queryText: "coffee")
  //  result.searchQueue.mostRecentResults = FixtureData.places.all
  result.searchDetent = .large
  return result
}

#Preview("show detail") {
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  let result = ContentView(searchQueue: searchQueue, queryText: "coffee")
  result.selectedPlace = FixtureData.places[.zeitgeist]
  return result
}

#Preview("Initial") {
  ContentView()
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
