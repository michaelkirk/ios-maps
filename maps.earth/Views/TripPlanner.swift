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

  var body: some View {
    VStack(alignment: .leading) {
      PlaceSearch(placeholder: "From", place: $navigateFrom)
      PlaceSearch(placeholder: "To", place: $navigateTo)
    }
  }
}

#Preview("'to' selected") {
  TripPlanner(navigateTo: FixtureData.places[0])
}

#Preview("'from' selected") {
  TripPlanner(navigateFrom: FixtureData.places[0])
}
