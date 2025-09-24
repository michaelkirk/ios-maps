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
  var didDismissSearch: () -> Void = {}
  var didSubmitSearch: () -> Void = {}
  @Binding var placeDetailsDetent: PresentationDetent

  @EnvironmentObject var userLocationManager: UserLocationManager
  @EnvironmentObject var preferences: Preferences
  @State private var selectedPlaceFromFavorite = false

  var body: some View {
    ScrollView {
      PlaceSearch(
        placeholder: "Where to?",
        hasPendingQuery: hasPendingQuery,
        places: $places,
        queryText: $queryText,
        canPickCurrentLocation: false,
        didDismissSearch: didDismissSearch,
        didSubmitSearch: didSubmitSearch,
        didSelectPlace: { place in
          selectedPlace = place
          selectedPlaceFromFavorite = false
        },
        slotContent: {
          if queryText.isEmpty && !preferences.favoritePlaces.isEmpty {
            FavoritePlaces(
              places: preferences.favoritePlaces,
              didSelect: { place in
                selectedPlace = place
                selectedPlaceFromFavorite = true
                didDismissSearch()
              }
            )
          }
        }
      )
    }.sheet(item: $selectedPlace) { place in
      PlaceDetailSheet(
        place: place, fromFavorite: selectedPlaceFromFavorite, tripPlan: tripPlan,
        presentationDetent: $placeDetailsDetent,
        onClose: { selectedPlace = nil },
        didCompleteTrip: { didDismissSearch() }  // better name for didDismissSearch
      )
      // This is arguably useful.
      // Usually I just want to swipe down to get a better look at the map without closing out
      // of the place. If I actually want to dismiss, it's easy enough to hit the X
      .interactiveDismissDisabled(true)
    }
  }
}

struct FavoritePlace: Codable, Equatable {
  let placeType: PlaceType
  let placeId: PlaceID
  let longitude: Float64
  let latitude: Float64
  var location: LngLat {
    LngLat(lng: longitude, lat: latitude)
  }
  var asPlace: Place {
    Place(
      location: self.location,
      properties: PlaceProperties(
        gid: self.placeId.serialized,
        name: self.name,
        label: self.name,
      )
    )
  }

  enum PlaceType: Codable, Equatable {
    case home
    case work
    case other(String)
  }

  var name: String {
    switch self.placeType {
    case .home: "Home"
    case .work: "Work"
    case .other(let name): name
    }
  }

  var icon: Image {
    switch self.placeType {
    case .home: Image(systemName: "house.fill")
    case .work: Image(systemName: "briefcase.fill")
    case .other: Image(systemName: "mappin")
    }
  }

  var saveButtonIcon: Image {
    switch self.placeType {
    case .home: Image(systemName: "house.fill")
    case .work: Image(systemName: "briefcase.fill")
    case .other: Image(systemName: "star.fill")
    }
  }

  var iconColor: Color {
    switch self.placeType {
    case .home: .hw_green
    case .work: .hw_red
    case .other: .hw_blue
    }
  }
}

extension FavoritePlace {
  init(placeType: PlaceType, lngLat: LngLat) {
    self.init(
      placeType: placeType, placeId: PlaceID.lngLat(lngLat), longitude: lngLat.lng,
      latitude: lngLat.lat)
  }

  init(place: Place) {
    self.placeType = .other(place.name)
    self.placeId = place.id
    self.longitude = place.lng
    self.latitude = place.lat
  }
}

struct FavoritePlaces: View {
  init(places: [FavoritePlace], didSelect: @escaping (Place) -> Void) {
    self.places = places
    self.didSelect = didSelect
  }

  let places: [FavoritePlace]
  var didSelect: (Place) -> Void = { _ in }
  var body: some View {
    VStack(alignment: .leading) {
      Text("Favorites").font(.headline)
        .padding(.horizontal)
      ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 12) {
          ForEach(Array(places.enumerated()), id: \.0) { idx, favoritePlace in
            Button(action: { didSelect(favoritePlace.asPlace) }) {
              VStack {
                favoritePlace.icon
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .foregroundStyle(Color.hw_offWhite)
                  .padding(13)
                  .frame(width: 64, height: 64)
                  .background(favoritePlace.iconColor)
                  .cornerRadius(32)
                Text(favoritePlace.name)
                  .foregroundColor(.black)
                  .lineLimit(1)
                  .frame(width: 70)
              }
            }
          }
        }.padding(.horizontal)
      }
    }
  }
}

#Preview("initial state") {
  FrontPageSearch(
    hasPendingQuery: false,
    places: .constant(nil),
    queryText: .constant(""),
    selectedPlace: .constant(nil),
    tripPlan: FixtureData.bikeTripPlan,
    placeDetailsDetent: .constant(.medium)
  )
  .environmentObject(Preferences.forTesting())
}

#Preview("show history") {
  return FrontPageSearch(
    hasPendingQuery: false,
    places: .constant(nil),
    queryText: .constant(""),
    selectedPlace: .constant(nil),
    tripPlan: FixtureData.bikeTripPlan,
    placeDetailsDetent: .constant(.medium)
  ).environmentObject(Preferences.forTesting())
}

#Preview("no results") {
  FrontPageSearch(
    hasPendingQuery: false,
    places: .constant([]),
    queryText: .constant("Really Obscure Coffee"),
    selectedPlace: .constant(nil),
    tripPlan: FixtureData.bikeTripPlan,
    placeDetailsDetent: .constant(.medium)
  ).environmentObject(Preferences.forTesting())
}

#Preview("coffee") {
  FrontPageSearch(
    hasPendingQuery: false,
    places: .constant(FixtureData.places.all),
    queryText: .constant("Coffee"),
    selectedPlace: .constant(nil),
    tripPlan: FixtureData.bikeTripPlan,
    placeDetailsDetent: .constant(.medium)
  ).environmentObject(Preferences.forTesting())
}
