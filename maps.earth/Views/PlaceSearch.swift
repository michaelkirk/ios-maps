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

struct PlaceField: View {
  var header: String
  @Binding var place: Place?
  @State var isSearching: Bool = false
  @State var queryText: String = ""
  @StateObject private var searchQueue: SearchQueue = SearchQueue()

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
    }.onChange(of: queryText) { oldValue, newValue in
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
  PlaceField(header: "From", place: .constant(nil), isSearching: true)
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
          }
        }
        Spacer()
      }.navigationTitle("Change Stop")
        .toolbar {
          Button(action: { dismiss() }) {
            Image(systemName: "xmark")
          }
        }
    }
    .onChange(of: isSearching) { oldValue, newValue in
      if oldValue && !newValue {
        dismissSearch()
        dismiss()
      }
    }
  }
}

struct FrontPagePlaceSearch: View {
  var placeholder: String
  var hasPendingQuery: Bool
  @Binding var places: [Place]?
  @Binding var queryText: String
  @Binding var selectedPlace: Place?
  @ObservedObject var tripPlan: TripPlan
  var didDismissSearch: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        HStack {
          Image(systemName: "magnifyingglass").foregroundColor(.hw_searchFieldPlaceholderForeground)
          TextField("Where to?", text: $queryText).dynamicTypeSize(.xxLarge)
          if queryText.count > 0 {
            Button(action: {
              queryText = ""
            }) {
              Image(systemName: "xmark.circle.fill")
            }.foregroundColor(.hw_searchFieldPlaceholderForeground)
          }
        }
        .padding(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
        .background(Color.hw_searchFieldBackground)
        .cornerRadius(10)
        if queryText.count > 0 {
          Button(action: {
            queryText = ""
            didDismissSearch()
          }) {
            Text("Cancel")
          }
        }
      }.padding()

      if hasPendingQuery {
        Text("Looking... 🧐")
      }
      if let places = places {
        if places.isEmpty && !hasPendingQuery {
          Text("No results. 😢")
        }
        PlaceList(places: $places, selectedPlace: $selectedPlace, tripPlan: tripPlan)
      }
      Spacer()
    }
  }
}

class SearchQueue: ObservableObject {
  @Published var mostRecentResults: [Place]?

  var env = Env.current
  var focus: LngLat? {
    env.getMapFocus()
  }

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

  init(mostRecentResults: [Place]? = nil) {
    self.mostRecentResults = mostRecentResults
  }

  func cancelInFlightQueries() {
    self.mostRecentResults = nil
    self.mostRecentlyCompletedQuery = nil
    self.pendingQueries = []
  }

  // TODO debounce
  func textDidChange(newValue: String) {
    search(text: newValue, focus: focus)
  }

  func search(text: String, focus: LngLat!) {
    let queryText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    logger.debug("search queryText '\(queryText)', focus: \(String(describing: focus))")

    let nextId = (pendingQueries.last?.queryId ?? 0) + 1
    let query = Query(queryId: nextId)
    pendingQueries.append(query)

    guard !queryText.isEmpty else {
      logger.debug("Clearing results for empty search field #\(query.queryId)")
      self.cancelInFlightQueries()
      return
    }

    Task {
      do {
        logger.debug("making query #\(query.queryId)")
        let results = try await GeocodeClient().autocomplete(
          text: queryText, focus: focus)

        await MainActor.run {
          if let mostRecentlyCompletedQuery = self.mostRecentlyCompletedQuery,
            query.queryId <= mostRecentlyCompletedQuery.queryId
          {
            logger.debug("Ignoring stale results for query #\(query.queryId)")
          } else {
            logger.debug("Updating results from query #\(query.queryId)")
            // FIXME: there is a race here if we've "cleared" pending queries while one is in progress.
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

//#Preview("blank") {
//  NavigationView {
//    PlaceSearch(
//      placeholder: "To", hasPendingQuery: false, selectedPlace: .constant(nil),
//  }.searchable(text: .constant(""))
//}

//#Preview("pending") {
//  PlaceSearch(
//    placeholder: "To", hasPendingQuery: true, selectedPlace: .constant(nil))
//}
