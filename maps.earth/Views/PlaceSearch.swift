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
  var getFocus: () -> LngLat?
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
      }.padding()
    }.onChange(of: queryText) { oldValue, newValue in
      searchQueue.textDidChange(newValue: newValue, focus: getFocus())
    }
    .sheet(isPresented: $isSearching) {
      PlaceSearch(
        placeholder: header,
        hasPendingQuery: searchQueue.hasPendingQuery,
        places: searchQueue.mostRecentResults,
        selectedPlace: $place,
        getFocus: getFocus
      ).searchable(text: $queryText)
    }
  }
}

#Preview("long name") {
  PlaceField(header: "From", place: .constant(FixtureData.places[.santaLucia]), getFocus: fakeFocus)
}
#Preview("short name") {
  PlaceField(header: "To", place: .constant(FixtureData.places[.zeitgeist]), getFocus: fakeFocus)
}

#Preview("empty place field") {
  PlaceField(header: "From", place: .constant(nil), getFocus: fakeFocus)
}

#Preview("searching place field") {
  PlaceField(header: "From", place: .constant(nil), isSearching: true, getFocus: fakeFocus)
}

struct PlaceSearch: View {
  var placeholder: String
  var hasPendingQuery: Bool
  var places: [Place]?
  @Binding var selectedPlace: Place?
  var getFocus: () -> LngLat?

  @Environment(\.isSearching) private var isSearching
  @Environment(\.dismissSearch) private var dismissSearch
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack {
        if hasPendingQuery {
          Text("Looking... 😓")
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
      print("isSearching changed: \(oldValue) -> \(newValue)")
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
  var getFocus: () -> LngLat?
  @Binding var selectedPlace: Place?
  @ObservedObject var tripPlan: TripPlan

  @Environment(\.isSearching) private var isSearching
  @Environment(\.dismissSearch) private var dismissSearch
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack {
        if hasPendingQuery {
          Text("Looking... 😓")
        }
        if let places = places {
          if places.isEmpty && !hasPendingQuery {
            Text("No results. 😢")
          }
          PlaceList(places: $places, selectedPlace: $selectedPlace, tripPlan: tripPlan)
        }
        Spacer()
      }
      //      .navigationBarHidden(true)
      .toolbar(.hidden, for: .navigationBar)
      .searchPresentationToolbarBehavior(.avoidHidingContent)
      .onChange(of: isSearching) { oldValue, newValue in
        print("FrontPagePlaceSearch isSearching changed: \(oldValue) -> \(newValue)")
        //      if oldValue && !newValue {
        //        dismissSearch()
        //        dismiss()
        //      }
      }
    }
  }
}

class SearchQueue: ObservableObject {
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

  init(mostRecentResults: [Place]? = nil) {
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
      self.mostRecentResults = nil
      self.mostRecentlyCompletedQuery = nil
      self.pendingQueries = []
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
  NavigationView {
    PlaceSearch(
      placeholder: "To", hasPendingQuery: false, selectedPlace: .constant(nil),
      getFocus: fakeFocus)
  }.searchable(text: .constant(""))
}

#Preview("pending") {
  PlaceSearch(
    placeholder: "To", hasPendingQuery: true, selectedPlace: .constant(nil), getFocus: fakeFocus)
}
