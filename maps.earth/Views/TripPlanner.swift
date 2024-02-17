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
      PlaceField(header: "From", place: $navigateFrom, getFocus: getFocus)
      Divider()
      PlaceField(header: "To", place: $navigateTo, getFocus: getFocus)
      Divider()
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
