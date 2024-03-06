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

  // eventually this should include mode choice
  @Binding var navigateTo: Place?

  @State var showingSheet: Bool

  var body: some View {
    VStack(alignment: .leading) {
      Text(place.name).font(.largeTitle)

      Button(action: { showingSheet = true }) {
        Text("Navigate")
      }
      .padding()
      .background(.blue)
      .foregroundColor(.white)
      .cornerRadius(3)
      .sheet(
        isPresented: $showingSheet,
        content: {
          NavigationView {
            ScrollView {
              // TODO: plumb focus from higher, or put in environment
              TripPlanView(to: place, getFocus: fakeFocus)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .navigationTitle("Directions")
            // FIXME: For some reason this is on a different line, pushing the nav title down
            .navigationBarItems(
              trailing: Button(action: { showingSheet = false }) {
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
  PlaceDetail(place: FixtureData.places[0], navigateTo: .constant(nil), showingSheet: false)
}

#Preview("showing sheet") {
  PlaceDetail(place: FixtureData.places[0], navigateTo: .constant(nil), showingSheet: true)
}
