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

struct Searcher {

}

struct ContentView: View {
  @State private var searchText: String = "Coffee"
  @State var searchResults: [Place]
  @State var selectedPlace: Place?

  //  let coordinator = Coordinator()

  var body: some View {
    VStack {
      TextField("Where to?", text: $searchText)
        .padding()
        .border(.gray)
        .padding()
      Text(selectedPlace?.label ?? "none selected")
      MapView(places: $searchResults, selectedPlace: $selectedPlace).edgesIgnoringSafeArea(.all)
      VStack {
        PlaceList(places: $searchResults, selectedPlace: $selectedPlace)
      }
    }.onAppear(perform: {
      print("searching on load")
      Task {
        do {
          // TODO: don't hardcode focus
          searchResults = try await GeocodeClient().autocomplete(text: self.searchText, focus: LngLat(lng: -118.0, lat: 34.0))
        } catch {
          print("error when fetching: \(error)")
        }
      }
    })
  }
}

#Preview {
  ContentView(searchResults: FixtureData.places)
}
