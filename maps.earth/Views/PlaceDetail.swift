//
//  PlaceDetail.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Foundation
import SwiftUI

struct PlaceDetail: View {
  var place: Place

  @ObservedObject var tripPlan: TripPlan

  var body: some View {
    let isShowingDirections = Binding(
      get: {
        let value = tripPlan.navigateTo != nil
        print("get presentSheet \(value)")
        return value
      },
      set: { newValue in
        print("set presentSheet \(newValue)")
      }
    )

    Button(action: {
      print("navigateTo: \(place))")
      tripPlan.navigateTo = place
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
          Text("Directions").font(.largeTitle)
          Spacer()
          Button(action: { tripPlan.navigateTo = nil }) {
            Image(systemName: "xmark")
          }.tint(.black)
        }.padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
        ScrollView {
          // TODO: plumb focus from higher, or put in environment
          TripPlanView(tripPlan: tripPlan, getFocus: fakeFocus)
            .containerRelativeFrame(.vertical)
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
        }
      }
      .background(Color.hw_offWhite)
      .presentationDetents([.large, .medium, .height(50)], selection: .constant(.medium))
      .presentationBackgroundInteraction(
        .enabled(upThrough: .medium)
      )
    }

    Text(place.label).padding(.top, 16)
  }
}

#Preview {
  PlaceDetail(place: FixtureData.places[.zeitgeist], tripPlan: TripPlan())
}

#Preview("showing sheet") {
  PlaceDetail(place: FixtureData.places[.zeitgeist], tripPlan: TripPlan())
}
