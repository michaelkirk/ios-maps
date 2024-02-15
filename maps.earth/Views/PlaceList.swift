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
      if let places = places {
        List(places, selection: $selectedPlace) { place in
          PlaceRow(place: place).onTapGesture {
            selectedPlace = place
          }
        }
      } else {
        Text("Loading...")
      }
  }
}

#Preview("inital") {
  PlaceList(places: .constant(FixtureData.places), selectedPlace: .constant(nil))
}

#Preview("selected") {
  PlaceList(places: .constant(FixtureData.places), selectedPlace: .constant(FixtureData.places[0]))
}
