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
    VStack(alignment: .leading) {
      Text(place.name).font(.largeTitle)

      Button(action: {
        print("navigateTo: \(place))")
        tripPlan.navigateTo = place
      }) {
        Text("Navigate")
      }
      .padding()
      .background(.blue)
      .foregroundColor(.white)
      .cornerRadius(3)
      .sheet(
        isPresented: Binding(
          get: {
            let value = tripPlan.navigateTo != nil
            print("get presentSheet \(value)")
            return value
          },
          set: { newValue in
            print("set presentSheet \(newValue)")
          }
        ),
        content: {
          NavigationView {
            ScrollView {
              // TODO: plumb focus from higher, or put in environment
              TripPlanView(tripPlan: ObservedObject(wrappedValue: tripPlan), getFocus: fakeFocus)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .navigationTitle("Directions")
            // FIXME: For some reason this is on a different line, pushing the nav title down
            .navigationBarItems(
              trailing: Button(action: { tripPlan.navigateTo = nil }) {
                Image(systemName: "xmark")
              })
          }
          .presentationDetents([.large, .medium, .height(50)], selection: .constant(.medium))
          .presentationBackgroundInteraction(
            .enabled(upThrough: .medium)
          )
        })

      Text(place.label).padding(.top, 16)
    }
  }
}

#Preview {
  PlaceDetail(place: FixtureData.places[0], tripPlan: TripPlan())
}

#Preview("showing sheet") {
  PlaceDetail(place: FixtureData.places[0], tripPlan: TripPlan())
}
