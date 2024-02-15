//
//  ContentView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import MapLibre
import OSLog
import SwiftUI

//class MapViewDelegate: NSObject, MLNMapViewDelegate {
//  func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
//    print("did select annotation \(annotation)")
//  }
//}

//class MapViewDelegate {
//  func mapView(_ mapView: MLNMapView, didSelectPlace place: Place) {
//    print("mapView did select place: \(place)")
//
//  }
//}
//
//class PlaceListDelegate {
//  func placeList(_ placeList: PlaceList, didSelectPlace place: Place) {
//    print("place list did select place: \(place)")
//  }
//}

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier!,
  category: String(describing: #file)
)

class SearchQueue: ObservableObject {
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

struct ContentView: View {
  @StateObject internal var toSearchQueue = SearchQueue()
  @State var selectedPlace: Place?

  @State var toPlace: Place?

  @StateObject internal var fromSearchQueue = SearchQueue()
  @State var fromPlace: Place?

  // I'm not currently using this... but I might
  @State var mapView: MLNMapView?

  var body: some View {
    MapView(
      places: $toSearchQueue.mostRecentResults, selectedPlace: $selectedPlace, mapView: $mapView
    )
    .edgesIgnoringSafeArea(.all)
    VStack(spacing: 0) {
      if toPlace != nil {
        TextField("From", text: $fromSearchQueue.searchText)
          .padding()
          .border(.gray)
          .padding()
          .onChange(of: fromSearchQueue.searchText) { _, newValue in
            let focus = (self.mapView?.centerCoordinate).map { LngLat(coord: $0) }
            self.fromSearchQueue.textDidChange(newValue: newValue, focus: focus)
          }
      }

      if selectedPlace == nil {
        TextField("Where to?", text: $toSearchQueue.searchText)
          .padding()
          .border(.gray)
          .padding()
          .onChange(of: toSearchQueue.searchText) { _, newValue in
            let focus = (self.mapView?.centerCoordinate).map { LngLat(coord: $0) }
            self.toSearchQueue.textDidChange(newValue: newValue, focus: focus)
          }
      }

      if !toSearchQueue.searchText.isEmpty && toPlace == nil {
        PlaceList(places: $toSearchQueue.mostRecentResults, selectedPlace: $selectedPlace)
      }
    }
  }
}

#Preview("blank") {
  ContentView()
}

#Preview("search") {
  ContentView(
    toSearchQueue: SearchQueue(searchText: "coffee", mostRecentResults: FixtureData.places))
}

#Preview("show detail") {
  ContentView(
    toSearchQueue: SearchQueue(searchText: "coffee", mostRecentResults: FixtureData.places),
    selectedPlace: FixtureData.places[0])
}

#Preview("nav from") {
  ContentView(
    toSearchQueue: SearchQueue(searchText: "coffee", mostRecentResults: FixtureData.places),
    selectedPlace: FixtureData.places[0],
    toPlace: FixtureData.places[0])
}
