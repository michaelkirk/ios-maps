//
//  TripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import SwiftUI

struct TripPlanner: View {
  @State var navigateFrom: Place?
  @State var navigateTo: Place?
  var getFocus: () -> LngLat?

  var body: some View {
    VStack(alignment: .leading) {
      PlaceSearch(placeholder: "From", selectedPlace: $navigateFrom, getFocus: getFocus)
      PlaceSearch(placeholder: "To", selectedPlace: $navigateTo, getFocus: getFocus)
    }
  }
}

func fakeFocus() -> LngLat? {
  LngLat(lng: -122.754113, lat: 47.079458)
}

#Preview("'to' selected") {
  TripPlanner(navigateTo: FixtureData.places[0], getFocus: fakeFocus)
}

#Preview("'from' selected") {
  TripPlanner(navigateFrom: FixtureData.places[0], getFocus: fakeFocus)
}
