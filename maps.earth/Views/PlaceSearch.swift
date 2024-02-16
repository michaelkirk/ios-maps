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
