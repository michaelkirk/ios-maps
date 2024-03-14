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
      get: {
        let value = tripPlan.navigateTo != nil || tripPlan.navigateFrom != nil
        print("get isShowingDirections \(value)")
        return value
      },
      set: { newValue in
        print("set isShowingDirections is no-op: \(newValue)")
      }
    )
    VStack {

      Button(action: {
        print("navigateTo: \(place))")
        tripPlan.navigateTo = place
        if let mostRecentUserLocation = self.userLocationManager.mostRecentUserLocation {
          print("got mostRecentUserLocation from env: \(mostRecentUserLocation)")
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
