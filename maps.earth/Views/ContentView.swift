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

let minDetentHeight: CGFloat = 72
struct ContentView: View {
  @State var selectedPlace: Place?
  @StateObject var tripPlan: TripPlan = TripPlan()

  @State var mapView: MLNMapView?

  @State var sheetIsPresented: Bool = true
  @StateObject private var searchQueue: SearchQueue = SearchQueue()
  @State var queryText: String = ""
  @State var searchDetent: PresentationDetent = .height(minDetentHeight)
  @Environment(\.isSearching) private var isSearching

  var presentedSheet: PresentedSheet = .search

  var body: some View {
    MapView(
      places: $searchQueue.mostRecentResults, selectedPlace: $selectedPlace, mapView: $mapView,
      tripPlan: tripPlan
    )
    .edgesIgnoringSafeArea(.all)
    .sheet(
      isPresented: Binding(
        get: {
          switch self.presentedSheet {
          case .search: true
          default: false
          }
        },
        set: { value in
          fatalError("can this be set? \(String(describing: value))")
        }
      )
    ) {
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
      .presentationDetents([.large, .medium, .height(minDetentHeight)], selection: $searchDetent)
      .presentationBackgroundInteraction(
        .enabled(upThrough: .medium)
      )
      .interactiveDismissDisabled(true)
    }
  }
}

enum PresentedSheet {
  case search
  case placeDetail(Binding<Place>)
}

//#Preview("search") {
//  ContentView(queryText: "coffee", mostRecentResults: FixtureData.places.all)
//}

//#Preview("show detail") {
//  ContentView(
//    selectedPlace: FixtureData.places[.zeitgeist],
//    toSearchQueue: LegacySearchQueue(
//      searchText: "coffee", mostRecentResults: FixtureData.places.all)
//  )
//}
//
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
