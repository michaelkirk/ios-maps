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
        Text("Navigate")
      }
      .padding()
      .foregroundColor(.white)
      .background(.blue)
      .cornerRadius(4)
      .sheet(isPresented: isShowingDirections) {
        VStack(spacing: 0) {
          HStack {
            Text("Directions").font(.title).bold()
            Spacer()
            CloseButton {
              tripPlan.clear()
            }
          }.padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
          ScrollView {
            // TODO: plumb focus from higher, or put in environment
            TripPlanView(tripPlan: tripPlan, getFocus: fakeFocus)
              .containerRelativeFrame(.vertical)
              .padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
          }
        }
        .background(Color.hw_sheetBackground)
        .presentationDetents([.large, .medium, minDetentHeight], selection: .constant(.medium))
        .presentationBackgroundInteraction(
          .enabled(upThrough: .medium)
        )
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
