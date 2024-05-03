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
  var didSelectPlace: (Place) -> Void

  var body: some View {
    if let places = places {
      VStack {
        ForEach(places) { place in
          PlaceRow(place: place).onTapGesture {
            dismissKeyboard()
            didSelectPlace(place)
          }
          .padding(.vertical, 4)
          Divider()
        }
      }

      // FIXME: I'd like to do this, but it dismisses the *entire* sheet
      // along with the keyboard. Presumably we're really just juggling
      // first responder here - and it's something that the sheet logic
      // reacts to, not just the keyboard.
      // .scrollDismissesKeyboard(.immediately)
    } else {
      Text("Loading...")
    }
  }
}

#Preview("inital") {
  PlaceList(
    places: .constant(FixtureData.places.all),
    didSelectPlace: { _ in })
}

#Preview("selected") {
  PlaceList(
    places: .constant(FixtureData.places.all),
    didSelectPlace: { _ in })
}
