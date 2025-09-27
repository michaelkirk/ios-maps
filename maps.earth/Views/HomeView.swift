//
//  HomeView.swift
//  maps.earth
//
//  Created by Michael Kirk on 1/29/24.
//

import MapLibre
import SwiftUI

private let logger = FileLogger()

func AssertMainThread() {
  assert(Thread.isMainThread)
}

let minDetentHeight = PresentationDetent.height(68)
let initialDetentHeight = PresentationDetent.medium
struct HomeView: View {
  @State var selectedPlace: Place?
  @ObservedObject @MainActor var tripPlan: TripPlan = TripPlan()
  @EnvironmentObject var preferences: Preferences

  @StateObject var searchQueue: SearchQueue = SearchQueue()
  @State var queryText: String = ""

  @State var searchDetent: PresentationDetent = initialDetentHeight
  @State var placeDetailsDetent: PresentationDetent = .medium

  @StateObject var userLocationManager = UserLocationManager()
  // start by zooming to the user's current location if we have it
  @State var pendingMapFocus: MapFocus? = .userLocation {
    didSet {
      print(
        "pendingMapFocus: \(String(describing: oldValue)) -> \(String(describing: pendingMapFocus))"
      )
    }
  }

  var body: some View {
    MapView(
      searchResults: $searchQueue.mostRecentResults, selectedPlace: $selectedPlace,
      pendingMapFocus: $pendingMapFocus,
      tripPlan: tripPlan
    )
    .environmentObject(userLocationManager)
    .edgesIgnoringSafeArea(.all)
    .sheet(isPresented: .constant(true)) {
      FrontPageSearch(
        hasPendingQuery: searchQueue.hasPendingQuery,
        places: $searchQueue.mostRecentResults,
        queryText: $queryText,
        selectedPlace: $selectedPlace,
        tripPlan: tripPlan,
        didDismissSearch: {
          queryText = ""
          searchDetent = initialDetentHeight
          dismissKeyboard()
        },
        didSubmitSearch: {
          searchDetent = .medium
          guard let mostRecentlySubmittedQuery = searchQueue.mostRecentlySubmittedQuery else {
            // submitted "search" with empty query, so nothing to do
            return
          }

          guard let mostRecentlyCompletedQuery = searchQueue.mostRecentlyCompletedQuery,
            mostRecentlyCompletedQuery.queryId >= mostRecentlySubmittedQuery.queryId
          else {
            // Wait for query to complete
            self.pendingMapFocus = .pendingSearchResults(mostRecentlySubmittedQuery)
            return
          }

          // query is already ready - zoom to results
          guard let mostRecentResults = searchQueue.mostRecentResults else {
            assertionFailure("mostRecentlySubmittedQuery, but no mostRecentResults")
            return
          }
          self.pendingMapFocus = .searchResults(mostRecentResults)
        },
        placeDetailsDetent: $placeDetailsDetent
      )
      .presentationDetents([.large, .medium, minDetentHeight], selection: $searchDetent)
      .presentationBackgroundInteraction(
        .enabled(upThrough: .medium)
      )
      .presentationDragIndicator(.visible)
      .interactiveDismissDisabled(true)
      .environmentObject(userLocationManager)
      .onChange(of: queryText) { newValue in
        searchQueue.textDidChange(newValue: newValue)
      }
    }.onAppear {
      switch CLLocationManager().authorizationStatus {
      case .notDetermined:
        break
      case .denied, .restricted:
        self.userLocationManager.state = .denied
      case .authorizedAlways, .authorizedWhenInUse:
        self.userLocationManager.state = .showing
        // TODO: on change? Consolidate location managers?
        Env.current.coreLocationProvider.startUpdating()
      @unknown default:
        break
      }
    }.onChange(of: selectedPlace) { newValue in
      logger.debug(
        "selectedPlace did change -> \(String(describing: newValue))"
      )
      if let newValue = newValue {
        self.pendingMapFocus = .place(newValue)
        self.searchDetent = minDetentHeight
        self.placeDetailsDetent = .medium
      } else if searchQueue.mostRecentResults != nil || !preferences.favoritePlaces.isEmpty {
        // return to previous search results
        self.searchDetent = .medium
      }
    }.onChange(of: tripPlan.selectedTrip) { newValue in
      logger.debug(
        "selectedTrip did change -> \(String(describing: newValue))"
      )
      if let newValue = newValue {
        self.pendingMapFocus = .trip(newValue)
        self.placeDetailsDetent = minDetentHeight
      } else {
        self.placeDetailsDetent = .medium
      }
    }.onChange(of: searchQueue.mostRecentResults) { newValue in
      if case .pendingSearchResults(let pendingQuery) = self.pendingMapFocus {
        guard let mostRecentlyCompletedQuery = searchQueue.mostRecentlyCompletedQuery else {
          // no query completed yet
          return
        }
        if mostRecentlyCompletedQuery.queryId >= pendingQuery.queryId {
          guard let mostRecentResults = searchQueue.mostRecentResults else {
            assertionFailure("mostRecentlySubmittedQuery, but no mostRecentResults")
            return
          }
          self.pendingMapFocus = .searchResults(mostRecentResults)
        }
      }
    }.onOpenURL { url in
      self.handleUniversalLink(url: url)
    }
    // For testing universal links you can feed a URL directly.
    // You can also run: `$ xcrun simctl openurl booted "https://dev.maps.earth/directions/foo"`
    // But then you are subject to any caching of the www hosted `.well-known/apple-app-site-association` that Apple's CDN might do (allegedly up to 24 hours of caching)
    //
    //    .onAppear {
    //      let placeUrl = URL(string:"https://maps.earth/place/openstreetmap%3Avenue%3Anode%2F2485251324")!
    //      let directionsUrl = URL(string:"https://maps.earth/directions/bicycle/openstreetmap%3Avenue%3Anode%2F2485251324/openstreetmap%3Avenue%3Away%2F12903132")!
    //      let url = directionsUrl
    //      self.handleUniversalLink(url: url)
    //    }
  }

  func handleUniversalLink(url: URL) {
    logger.debug("opened URL: \(url)")
    guard let universalLink = UniversalLink(url: url) else {
      assertionFailure("failed to build universalLink for \(url)")
      return
    }

    logger.debug("received universalLink: \(String(describing: universalLink))")
    switch universalLink {
    case .home:
      // do nothing, probably best not to destroy any current state.
      break
    case .place(let placeID):
      Task {
        do {
          guard let place = try await GeocodeClient().details(placeID: placeID) else {
            assertionFailure("unable to find place from url: \(url), placeID: \(placeID)")
            return
          }
          self.tripPlan.clear()
          self.selectedPlace = place
        } catch {
          logger.error("error while fetching place from url: \(url), error: \(error)")
        }
      }
    case .directions(let travelMode, let from, let to):
      Task {
        self.tripPlan.clear()
        do {
          Task {
            // Will the user be surprised that the preferred travel mode is set here?
            await Preferences.shared.setPreferredTravelMode(travelMode)
          }
          if let from {
            let fromPlace = try await GeocodeClient().details(placeID: from)
            self.tripPlan.navigateFrom = fromPlace
          }
          if let to {
            let toPlace = try await GeocodeClient().details(placeID: to)
            // This is a bit problematic, and I will probably regret it.
            // selectedPlace must be non-nil to present the route sheet.
            // *but* it might be disorienting to clobber an existing selected place.
            if selectedPlace == nil {
              selectedPlace = toPlace
            }
            self.tripPlan.navigateTo = toPlace
          }
        } catch {
          logger.error("error while fetching places from url: \(url), error: \(error)")
        }
      }
    }
  }
}

#Preview("Search") {
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  return HomeView(
    searchQueue: searchQueue, queryText: "coffee", searchDetent: .large
  )
  .environmentObject(Preferences.forTesting())
}

#Preview("Place") {
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  return HomeView(
    selectedPlace: FixtureData.places[.santaLucia], searchQueue: searchQueue, queryText: "coffee"
  )
  .environmentObject(Preferences.forTesting())
}

#Preview("Trip") {
  let tripPlan = FixtureData.transitTripPlan
  let searchQueue = SearchQueue(mostRecentResults: FixtureData.places.all)
  return HomeView(
    selectedPlace: tripPlan.navigateTo, tripPlan: tripPlan, searchQueue: searchQueue,
    queryText: "coffee"
  )
  .environmentObject(Preferences.forTesting())
}

#Preview("Init") {
  HomeView()
    .environmentObject(Preferences.forTesting())
}
