//
//  PlaceList.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Foundation
import SwiftUI

protocol PlaceListDelegate {

}

struct PlaceList: View {
  @Binding var places: [Place]?
  @Binding var selectedPlace: Place?

  var body: some View {
    NavigationSplitView {
      if let places = places {
        List(places, selection: $selectedPlace) { place in
          PlaceRow(place: place).onTapGesture {
            selectedPlace = place
          }
        }
      } else {
        Text("Loading...")
      }
    } detail: {
      selectedPlace.map { PlaceDetail(place: $0, navigateTo: .constant(nil), showingSheet: false) }
    }.padding(0)
  }
}

#Preview("inital") {
  PlaceList(places: .constant(FixtureData.places), selectedPlace: .constant(nil))
}

#Preview("selected") {
  PlaceList(places: .constant(FixtureData.places), selectedPlace: .constant(FixtureData.places[0]))
}
