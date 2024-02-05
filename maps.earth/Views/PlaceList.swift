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
  @State var places: [Place]
  @Binding var selectedPlace: Place?

  var body: some View {
    NavigationSplitView {
      List(places, selection: $selectedPlace) { place in
        PlaceRow(place: place).onTapGesture {
          selectedPlace = place
        }
      }
    } detail: {
      selectedPlace.map { PlaceDetail(place: $0) }
    }
  }
}

#Preview("inital") {
  PlaceList(places: FixtureData.places, selectedPlace: .constant(nil))
}

#Preview("selected") {
  PlaceList(places: FixtureData.places, selectedPlace: .constant(FixtureData.places[0]))
}
