//
//  SearchResultRow.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Foundation
import SwiftUI

struct PlaceRow: View {
  var place: Place

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(place.label).font(.headline)
        if let formattedAddress = AddressFormatter().format(place: place) {
          Text(formattedAddress).font(.subheadline)
        }
      }
      Spacer()
    }
  }
}

#Preview {
  Group {
    PlaceRow(place: FixtureData.places[.zeitgeist])
    PlaceRow(place: FixtureData.places[.realfine])
  }
}
