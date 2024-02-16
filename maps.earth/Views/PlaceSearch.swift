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
  @Binding var place: Place?
  @StateObject private var searchQueue: SearchQueue = SearchQueue()
  @State private var showEditor: Bool

  init(
    placeholder: String, place: Binding<Place?>, showEditor: Bool = false,
    getFocus: @escaping () -> LngLat?
  ) {
    self.placeholder = placeholder
    self._place = place
    self.showEditor = showEditor
    self.getFocus = getFocus
    if let place = place.wrappedValue {
      // Need to do something like this to set initial search text
      self._searchQueue = StateObject(wrappedValue: SearchQueue(searchText: place.name))
    }
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
        TextField(placeholder, text: $searchQueue.searchText)
          .onChange(of: searchQueue.searchText) {
            // invalidate the place selection if the user changes the input text
            // note: this is also called due to the "clear" button
            place = nil

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
    }
  }
}

class SearchQueue: ObservableObject {
  @Published var searchText: String
  @Published var mostRecentResults: [Place]?

  struct Query {
    let queryId: UInt64
  }
  var pendingQueries: [Query] = []
  var mostRecentlyCompletedQuery: Query?

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

#Preview {
  PlaceSearch(
    placeholder: "my placeholder", place: .constant(nil), showEditor: false, getFocus: fakeFocus)
}
