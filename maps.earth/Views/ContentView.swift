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
      MapView(places: searchResults, selectedPlace: $selectedPlace).edgesIgnoringSafeArea(.all)
      VStack {
        PlaceList(places: searchResults, selectedPlace: $selectedPlace)
      }
    }
  }

  //  class Coordinator: NSObject, MapViewDelegate, PlaceListDelegate {
  //    func mapView(mapView: MLNMapView, didSelect place: Place) {
  //      // TODO: minZoom
  //      print("selected \(place)")
  //      mapView.setCenter(place.location.asCoordinate, animated: true)
  //      self.selectedPlace = place
  //    }
  //  }
}

#Preview {
  ContentView(searchResults: FixtureData.places)
}
