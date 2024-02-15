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
      Text(place.name).font(.largeTitle)

      Button(action: { print("clicked") }) {
        Text("Navigate")
      }
      .padding()
      .background(.blue)
      .foregroundColor(.white)
      .cornerRadius(3)
      Text(place.label).padding(.top, 16)
    }
  }
}

#Preview {
  PlaceDetail(place: FixtureData.places[0])
}
