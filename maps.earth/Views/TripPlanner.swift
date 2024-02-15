//
//  TripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import SwiftUI

struct TripPlanner: View {
  var navigateFrom: Place?
  var navigateTo: Place?

  var body: some View {
    VStack(alignment: .leading) {
      Text("From: \(navigateFrom?.name ?? "none")")
      Text("To: \(navigateTo?.name ?? "none")")
    }
  }
}

#Preview("pick from") {
  TripPlanner(navigateTo: FixtureData.places[0])
}
