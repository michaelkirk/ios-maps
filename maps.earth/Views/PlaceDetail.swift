//
//  PlaceDetail.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import CoreLocation
import Foundation
import SwiftUI

struct PlaceDetail: View {
  var place: Place

  @EnvironmentObject var userLocationManager: UserLocationManager
  @ObservedObject var tripPlan: TripPlan

  var body: some View {
    let isShowingDirections = Binding(
      get: { () -> Bool in
        let value = tripPlan.navigateTo != nil || tripPlan.navigateFrom != nil
        return value
      },
      set: { newValue in
      }
    )
    VStack {
      Button(action: {
        tripPlan.navigateTo = place
        if let mostRecentUserLocation = self.userLocationManager.mostRecentUserLocation {
          tripPlan.navigateFrom = Place(currentLocation: mostRecentUserLocation)
        }
      }) {
        Text("Directions")
      }
      .padding()
      .foregroundColor(.white)
      .background(.blue)
      .cornerRadius(4)
      .sheet(isPresented: isShowingDirections) {
        TripPlanSheetContents(tripPlan: tripPlan)
          .interactiveDismissDisabled()
      }

      Text(place.label).padding(.top, 16)
    }
  }
}

#Preview {
  PlaceDetail(place: FixtureData.places[.zeitgeist], tripPlan: TripPlan())
}

#Preview("showing sheet") {
  PlaceDetail(place: FixtureData.places[.zeitgeist], tripPlan: TripPlan())
}
