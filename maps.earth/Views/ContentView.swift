//
//  ContentView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import MapLibre
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

import OSLog

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier!,
  category: String(describing: #file)
)


class SearchQueue: ObservableObject {
  @Published var searchText: String
  @Published var mostRecentResults: [Place]

  init(searchText: String = "", mostRecentResults: [Place] = []) {
    self.searchText = searchText
    self.mostRecentResults = mostRecentResults
  }

  // TODO debounce, handle out of order
  func textDidChange(oldValue: String, newValue: String) {
    Task {
      do {
        // TODO: don't hardcode focus
        self.mostRecentResults = try await GeocodeClient().autocomplete(
          text: newValue, focus: LngLat(lng: -118.0, lat: 34.0))
      } catch {
        logger.info("TODO: handle error in SearchQueue.textDidChange: \(error)")
      }
    }
  }
}

struct ContentView: View {
  @StateObject internal var searchQueue = SearchQueue()
  //  @State var searchResults: [Place]
  @State var selectedPlace: Place?

  //  let coordinator = Coordinator()

  var body: some View {
    VStack {
      TextField("Where to?", text: $searchQueue.searchText)
        .padding()
        .border(.gray)
        .padding()
        .onChange(of: searchQueue.searchText) { oldValue, newValue in
          self.searchQueue.textDidChange(oldValue: oldValue, newValue: newValue)
        }
      Text(selectedPlace?.label ?? "none selected")
      MapView(places: $searchQueue.mostRecentResults, selectedPlace: $selectedPlace)
        .edgesIgnoringSafeArea(.all)
      VStack {
        PlaceList(places: $searchQueue.mostRecentResults, selectedPlace: $selectedPlace)
      }
    }.onAppear(perform: {
      logger.info("searching on load")
      Task {
        do {
          // TODO: don't hardcode focus
          //          self.searchQueue.mostRecentResults = try await GeocodeClient().autocomplete(text: self.searchQueue.searchText, focus: LngLat(lng: -118.0, lat: 34.0))
        } catch {
          print("error when fetching: \(error)")
        }
      }
    })
  }
}

#Preview {
  let cv = ContentView()
  cv.searchQueue.mostRecentResults = FixtureData.places
  return cv
}
