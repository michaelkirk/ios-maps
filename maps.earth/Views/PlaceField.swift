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
  @State var isSearching: Bool = false
  @State var queryText: String = ""
  @StateObject var searchQueue: SearchQueue = SearchQueue()

  var body: some View {
    Button(action: { isSearching = true }) {
      HStack(spacing: 16) {
        Text("\(header):").foregroundColor(.hw_darkGray)
          // this minWidth is intended to approximately align the To/From heafer
          // but it's brittle to dynamic type and locale specific
          .frame(minWidth: 40, alignment: .trailing)
        Text(place?.name ?? "None").foregroundColor(.black)
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("Edit")
      }.padding(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }.onChange(of: queryText) { newValue in
      searchQueue.textDidChange(newValue: newValue)
    }
    .sheet(isPresented: $isSearching) {
      PlaceSearch(
        placeholder: header,
        hasPendingQuery: searchQueue.hasPendingQuery,
        places: searchQueue.mostRecentResults,
        selectedPlace: $place
      ).searchable(text: $queryText)
    }
  }
}

struct PlaceSearch: View {
  var placeholder: String
  var hasPendingQuery: Bool
  var places: [Place]?
  @Binding var selectedPlace: Place?

  @Environment(\.isSearching) private var isSearching
  @Environment(\.dismissSearch) private var dismissSearch
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack {
        if hasPendingQuery {
          Text("Looking... 🧐")
        }
        if let places = places {
          if places.isEmpty && !hasPendingQuery {
            Text("No results. 😢")
          }
          List(places, selection: $selectedPlace) { place in
            PlaceRow(place: place).onTapGesture {
              print("selected a place, dismissing search")
              selectedPlace = place
              dismissSearch()
              dismiss()
            }
          }.hwListStyle()
        }
        Spacer()
      }
      // TODO: This should be "sheetColor" but it doesnt play nice with the built in
      // search controller
      .background(Color.white)
      .navigationTitle("Change Stop")
      .toolbar {
        Button(action: { dismiss() }) {
          Image(systemName: "xmark")
        }
      }
    }
    .onChange(of: isSearching) { newValue in
      if !newValue {
        dismissSearch()
        dismiss()
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
    header: "From", place: .constant(nil), isSearching: true, searchQueue: searchQueue)
}
