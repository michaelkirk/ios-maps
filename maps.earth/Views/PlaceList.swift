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

  var body: some View {
    let hasSelectedPlace = Binding(
      get: { selectedPlace != nil },
      set: { newValue in
        if newValue {
          assert(selectedPlace != nil)
        } else {
          selectedPlace = nil
        }
      })

    if let places = places {
      List(places, selection: $selectedPlace) { place in
        PlaceRow(place: place).onTapGesture {
          hideKeyboard()
          selectedPlace = place
        }
      }
      // FIXME: I'd like to do this, but it dismisses the *entire* sheet
      // along with the keyboard. Presumably we're really just juggling
      // first responder here - and it's something that the sheet logic
      // reacts to, not just the keyboard.
      // .scrollDismissesKeyboard(.immediately)
      .sheet(isPresented: hasSelectedPlace) {
        if let selectedPlace = selectedPlace {
          HStack {
            Text(selectedPlace.name).font(.largeTitle)
            Spacer()
            Button(action: { self.selectedPlace = nil }) {
              Image(systemName: "xmark")
            }.tint(.black)
          }.padding(EdgeInsets(top: 16, leading: 16, bottom: 0, trailing: 16))
          ScrollView {
            PlaceDetail(place: selectedPlace, tripPlan: tripPlan)
          }
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
