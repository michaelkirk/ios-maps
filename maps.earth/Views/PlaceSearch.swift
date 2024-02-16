//
//  PlaceSearch.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/15/24.
//

import Foundation
import OSLog
import SwiftUI

private let logger = Logger(
  subsystem: Bundle.main.bundleIdentifier!,
  category: String(describing: #file)
)

struct PlaceSearch: View {
  var placeholder: String
  var getFocus: () -> LngLat?
  @Binding var selectedPlace: Place?

  @StateObject private var searchQueue: SearchQueue = SearchQueue()
  @State private var showEditor: Bool

  init(
    placeholder: String, selectedPlace: Binding<Place?>, showEditor: Bool = false,
    getFocus: @escaping () -> LngLat?, existingResults: [Place]? = nil
  ) {
    self.placeholder = placeholder
    self._selectedPlace = selectedPlace
    self.showEditor = showEditor
    self.getFocus = getFocus

    let searchQueue = SearchQueue()
    if let place = selectedPlace.wrappedValue {
      searchQueue.searchText = place.name
    }
    if let existingResults = existingResults {
      searchQueue.mostRecentResults = existingResults
    }
    self._searchQueue = StateObject(wrappedValue: searchQueue)
  }

  var body: some View {
    HStack {
      // i18n review
      Text("\(placeholder): \(selectedPlace?.name ?? "None")").searchable(text: $searchQueue.searchText)
      Spacer()
      Button("Edit", action: { showEditor = true })
    }.padding().sheet(isPresented: $showEditor) {
      VStack {
        HStack {
          TextField(placeholder, text: $searchQueue.searchText)
            .onChange(of: searchQueue.searchText) {
              // invalidate the place selection if the user changes the input text
              // note: this is also called due to the "clear" button
              selectedPlace = nil

              searchQueue.textDidChange(newValue: searchQueue.searchText, focus: getFocus())
            }
          Spacer()
          if !searchQueue.searchText.isEmpty {
            // FIXME: clear no longer works now that property lives on searchQueue
            Button(action: {
              print("clearing: \(String(describing: searchQueue.searchText))")
              searchQueue.searchText = ""
            }) {
              Image(systemName: "x.circle.fill").tint(.black)
            }
          }
        }
        .padding(8)
        .border(.black)
        if searchQueue.hasPendingQuery {
          Text("Loading...")
        } else if let places = searchQueue.mostRecentResults {
          List(places, selection: $selectedPlace) { place in
            PlaceRow(place: place).onTapGesture {
              selectedPlace = place
              showEditor = false
            }
          }.frame(minWidth: 100, maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
          Text("After list")
        } else {
          Text("No search has started.")
        }
      }
    }
  }
}

class SearchQueue: ObservableObject {
  @Published var searchText: String
  @Published var mostRecentResults: [Place]?

  struct Query: Equatable {
    let queryId: UInt64
  }
  // perf: we could prune this as queries complete, but we'd need to update `hasPendingQuery`
  // to ignore "stale" queries in pendingQueries.
  private var pendingQueries: [Query] = []
  var mostRecentlyCompletedQuery: Query?

  var hasPendingQuery: Bool {
    guard let mostRecentlyMadeQuery = pendingQueries.last else {
      return false
    }

    guard let mostRecentlyCompletedQuery = mostRecentlyCompletedQuery else {
      return true
    }

    return mostRecentlyMadeQuery.queryId > mostRecentlyCompletedQuery.queryId
  }

  init(searchText: String = "", mostRecentResults: [Place]? = nil) {
    self.searchText = searchText
    self.mostRecentResults = mostRecentResults
  }

  // TODO debounce
  func textDidChange(newValue: String, focus: LngLat?) {
    logger.info("text did change to \(newValue), focus: \(String(describing: focus))")

    let nextId = (pendingQueries.last?.queryId ?? 0) + 1
    let query = Query(queryId: nextId)
    pendingQueries.append(query)

    guard !newValue.isEmpty else {
      logger.info("Clearing results for empty search field #\(query.queryId)")
      self.mostRecentResults = []
      return
    }

    Task {
      do {
        logger.info("making query #\(query.queryId)")
        let results = try await GeocodeClient().autocomplete(
          text: newValue, focus: focus)

        await MainActor.run {
          if let mostRecentlyCompletedQuery = self.mostRecentlyCompletedQuery,
            query.queryId <= mostRecentlyCompletedQuery.queryId
          {
            logger.info("Ignoring stale results for query #\(query.queryId)")
          } else {
            logger.info("Updating results from query #\(query.queryId)")
            self.mostRecentlyCompletedQuery = query
            self.mostRecentResults = results
          }
        }
      } catch {
        logger.info("TODO: handle error in SearchQueue.textDidChange: \(error)")
      }
    }
  }
}

#Preview("blank") {
  PlaceSearch(
    placeholder: "my placeholder", selectedPlace: .constant(nil), showEditor: false,
    getFocus: fakeFocus)
}

#Preview("selected") {
  PlaceSearch(
    placeholder: "my placeholder", selectedPlace: .constant(FixtureData.places[0]),
    showEditor: false, getFocus: fakeFocus)
}

#Preview("searching with none selected") {
  PlaceSearch(
    placeholder: "my placeholder", selectedPlace: .constant(nil), showEditor: true,
    getFocus: fakeFocus, existingResults: FixtureData.places)
}

#Preview("searching with previous selection") {
  PlaceSearch(
    placeholder: "my placeholder", selectedPlace: .constant(FixtureData.places[0]),
    showEditor: true, getFocus: fakeFocus, existingResults: FixtureData.places)
}
