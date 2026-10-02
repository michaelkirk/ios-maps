//
//  PlaceSearch.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import SwiftUI

private let logger = FileLogger()

struct PlaceField: View {
  var header: String
  @Binding var place: Place?
  var trailingInset: CGFloat = 16
  @State var searchIsPresented: Bool = false
  @State var queryText: String = ""
  @StateObject var searchQueue: SearchQueue = SearchQueue()
  @ScaledMetric var headerWidth: CGFloat = 48

  var body: some View {
    Button(action: { searchIsPresented = true }) {
      HStack(spacing: 16) {
        Text("\(header):").foregroundColor(.hw_darkGray)
          .frame(width: headerWidth, alignment: .trailing)
        Text(place?.name ?? "None").foregroundColor(.black)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: trailingInset))
      .contentShape(Rectangle())
    }.onChange(of: queryText) { newValue in
      searchQueue.textDidChange(newValue: newValue)
    }
    .sheet(isPresented: $searchIsPresented) {
      SheetContents(
        title: "Change Stop", onClose: { searchIsPresented = false },
        currentDetent: .constant(.large)
      ) {
        ScrollView {
          PlaceSearch(
            placeholder: header,
            hasPendingQuery: searchQueue.hasPendingQuery,
            places: $searchQueue.mostRecentResults,
            queryText: $queryText,
            canPickCurrentLocation: true,
            didDismissSearch: {
              searchIsPresented = false
            },
            didSubmitSearch: {
              searchIsPresented = false
            },
            didSelectPlace: { newPlace in
              searchIsPresented = false
              place = newPlace
            }
          )
        }
      }
    }
  }
}

#Preview("long name") {
  PlaceField(header: "From", place: .constant(FixtureData.places[.santaLucia]))
}
#Preview("short name") {
  PlaceField(header: "To", place: .constant(FixtureData.places[.zeitgeist]))
}

#Preview("empty place field") {
  PlaceField(header: "From", place: .constant(nil))
}

#Preview("searching place field") {
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  return PlaceField(
    header: "From", place: .constant(nil), searchIsPresented: true, searchQueue: searchQueue)
}
