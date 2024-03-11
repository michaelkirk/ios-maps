//
//  PlaceList.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Foundation
import SwiftUI

protocol PlaceListDelegate {

}

struct PlaceList: View {
  @Binding var places: [Place]?
  @Binding var selectedPlace: Place?
  @ObservedObject var tripPlan: TripPlan
  @State var isShowingDetailSheet: Bool = false
  var body: some View {
    if let places = places {
      List(places, selection: $selectedPlace) { place in
        PlaceRow(place: place).onTapGesture {
          print("selected place")
          isShowingDetailSheet = true
          selectedPlace = place
        }
      }.sheet(isPresented: $isShowingDetailSheet) {
        if let selectedPlace = selectedPlace {
          PlaceDetail(place: selectedPlace, tripPlan: tripPlan)
            .presentationDetents([.large, .medium, minDetentHeight], selection: .constant(.medium))
            .presentationBackgroundInteraction(
              .enabled(upThrough: .medium)
            ).onDisappear {
              self.selectedPlace = nil
            }
            .interactiveDismissDisabled(true)
        }
      }
    } else {
      Text("Loading...")
    }
  }
}

#Preview("inital") {
  PlaceList(
    places: .constant(FixtureData.places.all), selectedPlace: .constant(nil), tripPlan: TripPlan()
  )
}

#Preview("selected") {
  PlaceList(
    places: .constant(FixtureData.places.all),
    selectedPlace: .constant(FixtureData.places[.zeitgeist]),
    tripPlan: TripPlan())
}
