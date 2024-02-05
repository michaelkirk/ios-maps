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
  var body: some View {
    VStack(alignment: .leading) {
      Text("Details")
      Text(place.name)
      Text(place.label)
    }
  }
}

#Preview {
  PlaceDetail(place: FixtureData.places[0])
}
