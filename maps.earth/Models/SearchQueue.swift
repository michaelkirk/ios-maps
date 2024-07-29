//
//  SearchQueue.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import Foundation

private let logger = FileLogger()

class SearchQueue: ObservableObject {
  @Published var mostRecentResults: [Place]?

  @MainActor
  var env = Env.current

  @MainActor
  var focus: LngLat? {
    env.getMapFocus()
  }

  struct Query: Equatable {
    let queryId: UInt64
  }
  // perf: we could prune this as queries complete, but we'd need to update `hasPendingQuery`
  // to ignore "stale" queries in pendingQueries.
  private var pendingQueries: [Query] = []
  @Published var mostRecentlyCompletedQuery: Query?
  @Published var mostRecentlySubmittedQuery: Query?

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
  @MainActor
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

    mostRecentlySubmittedQuery = query

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
            guard pendingQueries.contains(query) else {
              logger.debug("completed query was canceled")
              return
            }
            logger.debug("Updating results from query #\(query.queryId)")
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
