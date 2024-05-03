//
//  FrontPageSearch.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import SwiftUI

struct FrontPageSearch: View {
  var hasPendingQuery: Bool
  @Binding var places: [Place]?
  @Binding var queryText: String
  @Binding var selectedPlace: Place?
  @ObservedObject var tripPlan: TripPlan
  var didDismissSearch: () -> Void
  var didSubmitSearch: () -> Void
  @Binding var placeDetailsDetent: PresentationDetent

  @EnvironmentObject var userLocationManager: UserLocationManager

  var body: some View {
    let hasSelectedPlace = Binding(
      get: { selectedPlace != nil },
      set: { newValue in
        if newValue {
          assert(selectedPlace != nil)
        } else {
          selectedPlace = nil
        }
      })

    PlaceSearch(
      placeholder: "Where to?", hasPendingQuery: hasPendingQuery, places: $places,
      queryText: $queryText, didDismissSearch: didDismissSearch,
      didSubmitSearch: didSubmitSearch,
      didSelectPlace: { place in
        selectedPlace = place
      }
    ).sheet(isPresented: hasSelectedPlace) {
      if let selectedPlace = selectedPlace {
        SheetContents(
          title: selectedPlace.name,
          onClose: {
            self.selectedPlace = nil
          },
          currentDetent: $placeDetailsDetent
        ) {
          ScrollView {
            PlaceDetail(
              place: selectedPlace, tripPlan: tripPlan,
              didSelectNavigateTo: { place in
                tripPlan.navigateTo = place
                if let mostRecentUserLocation = self.userLocationManager
                  .mostRecentUserLocation
                {
                  tripPlan.navigateFrom = Place(currentLocation: mostRecentUserLocation)
                }
              })
          }
          // This is arguably useful.
          // Usually I just want to swipe down to get a better look at the map without closing out
          // of the place. If I actually want to dismiss, it's easy enough to hit the X
          .interactiveDismissDisabled(true)
        }
      }
    }
  }
}
