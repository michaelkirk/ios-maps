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
          dismissKeyboard()
          selectedPlace = place
        }
        .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .background(Color.hw_sheetBackground)
      }
      .listStyle(.plain)

      // FIXME: I'd like to do this, but it dismisses the *entire* sheet
      // along with the keyboard. Presumably we're really just juggling
      // first responder here - and it's something that the sheet logic
      // reacts to, not just the keyboard.
      // .scrollDismissesKeyboard(.immediately)
      .sheet(isPresented: hasSelectedPlace) {
        if let selectedPlace = selectedPlace {
          SheetContents(
            title: selectedPlace.name,
            onClose: {
              self.selectedPlace = nil
            }
          ) {
            ScrollView {
              PlaceDetail(place: selectedPlace, tripPlan: tripPlan)
            }
            // This is arguably useful.
            // Usually I just want to swipe down to get a better look at the map without closing out
            // of the place. If I actually want to dismiss, it's easy enough to hit the X
            .interactiveDismissDisabled(true)
          }
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
