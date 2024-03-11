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

class LegacySearchQueue: ObservableObject {
  @Published var searchText: String
  @Published var mostRecentResults: [Place]?

  struct Query {
    let queryId: UInt64
  }
  var pendingQueries: [Query] = []
  var mostRecentlyCompletedQuery: Query?

  init(searchText: String = "", mostRecentResults: [Place]? = nil) {
    self.searchText = searchText
    self.mostRecentResults = mostRecentResults
  }

  // TODO debounce
  func textDidChange(newValue: String, focus: LngLat?) {
    let nextId = (pendingQueries.last?.queryId ?? 0) + 1
    let query = Query(queryId: nextId)
    pendingQueries.append(query)

    guard !newValue.isEmpty else {
      logger.info("Clearing results for empty search field #\(query.queryId)")
      self.mostRecentResults = []
      return
    }

    Task {
      do {
        logger.info("making query #\(query.queryId)")
        let results = try await GeocodeClient().autocomplete(
          text: newValue, focus: focus)

        await MainActor.run {
          if let mostRecentlyCompletedQuery = self.mostRecentlyCompletedQuery,
            query.queryId <= mostRecentlyCompletedQuery.queryId
          {
            logger.info("Ignoring stale results for query #\(query.queryId)")
          } else {
            logger.info("Updating results from query #\(query.queryId)")
            self.mostRecentlyCompletedQuery = query
            self.mostRecentResults = results
          }
        }
      } catch {
        logger.info("TODO: handle error in SearchQueue.textDidChange: \(error)")
      }
    }
  }
}

let minDetentHeight: CGFloat = 72
struct ContentView: View {
  @State var selectedPlace: Place?
  @StateObject var tripPlan: TripPlan = TripPlan()

  //  @StateObject internal var toSearchQueue = LegacySearchQueue()

  // I'm not currently using this... but I might
  @State var mapView: MLNMapView?

  @State var sheetIsPresented: Bool = true
  @StateObject private var searchQueue: SearchQueue = SearchQueue()
  @State var queryText: String = ""
  @State var searchDetent: PresentationDetent = .height(minDetentHeight)
  @Environment(\.isSearching) private var isSearching

  var body: some View {
    MapView(
      places: $searchQueue.mostRecentResults, selectedPlace: $selectedPlace, mapView: $mapView,
      tripPlan: tripPlan
    )
    .edgesIgnoringSafeArea(.all)
    .sheet(isPresented: $sheetIsPresented) {
      FrontPagePlaceSearch(
        placeholder: "Where to?",
        hasPendingQuery: searchQueue.hasPendingQuery,
        places: $searchQueue.mostRecentResults,
        queryText: $queryText,
        getFocus: fakeFocus,
        selectedPlace: $selectedPlace,
        tripPlan: tripPlan
      )
      .onChange(of: queryText) { oldValue, newValue in
        searchQueue.textDidChange(newValue: newValue, focus: fakeFocus())
      }
      .scenePadding(.top)
      //      .padding(EdgeInsets(top: -40, leading: 0, bottom: 0, trailing: 0))
      //      .ignoresSafeArea()
      //      .searchable(text: $queryText)
      // BECOME first responder
      //      .searchable(text: $queryText, isPresented: .constant(true))
      //      .searchPresentationToolbarBehavior(.avoidHidingContent)
      .presentationDetents([.large, .medium, .height(minDetentHeight)], selection: $searchDetent)
      .presentationBackgroundInteraction(
        .enabled(upThrough: .medium)
      ).onChange(of: isSearching) { oldValue, newValue in
        print("ContentView isSearching changed: \(oldValue) -> \(newValue)")
      }
      .interactiveDismissDisabled(true)
    }

    //    VStack(spacing: 0) {
    //      // FIX: bad animation as this becomes visible upon "back" from details
    //      if selectedPlace == nil {
    //        TextField("Where to?", text: $toSearchQueue.searchText)
    //          .padding()
    //          .border(.gray)
    //          .padding()
    //          .onChange(of: toSearchQueue.searchText) { _, newValue in
    //            let focus = (self.mapView?.centerCoordinate).map { LngLat(coord: $0) }
    //            self.toSearchQueue.textDidChange(newValue: newValue, focus: focus)
    //          }
    //      }
    //
    //      if !toSearchQueue.searchText.isEmpty {
    //        PlaceList(
    //          places: $toSearchQueue.mostRecentResults, selectedPlace: $selectedPlace,
    //          tripPlan: tripPlan)
    //      }
    //    }
  }
}

//#Preview("search") {
//  ContentView(
//    toSearchQueue: LegacySearchQueue(
//      searchText: "coffee", mostRecentResults: FixtureData.places.all))
//}
//
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
