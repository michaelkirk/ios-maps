//
//  TripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import SwiftUI

struct PlaceSearch: View {
  var placeholder: String
  @Binding var place: Place?
  @State private var searchText: String
  @State private var showEditor: Bool

  init(
    placeholder: String, place: Binding<Place?>, searchText: String = "", showEditor: Bool = false
  ) {
    self.placeholder = placeholder
    self._place = place
    self.searchText = place.wrappedValue?.name ?? searchText
    self.showEditor = showEditor
  }

  var body: some View {
    if !showEditor, let place = place {
      HStack {
        // i18n review
        Text("\(placeholder): \(place.name)")
        Spacer()
        Button("Edit", action: { showEditor = true })
      }.padding()
    } else {
      HStack {
        TextField(placeholder, text: $searchText)
          .onChange(of: searchText) {
            // invalidate the place selection if the user changes the input text
            // not this works for the "clear" button too.
            place = nil
          }
        Spacer()
        if !searchText.isEmpty {
          Button(action: { searchText = "" }) {
            Image(systemName: "x.circle.fill").tint(.black)
          }
        }
      }
      .padding(8)
      .border(.black)
    }
  }
}

struct TripPlanner: View {
  @State var navigateFrom: Place?
  @State var navigateTo: Place?

  var body: some View {
    VStack(alignment: .leading) {
      PlaceSearch(placeholder: "From", place: $navigateFrom)
      PlaceSearch(placeholder: "To", place: $navigateTo)
    }
  }
}

#Preview("'to' selected") {
  TripPlanner(navigateTo: FixtureData.places[0])
}

#Preview("'from' selected") {
  TripPlanner(navigateFrom: FixtureData.places[0])
}
