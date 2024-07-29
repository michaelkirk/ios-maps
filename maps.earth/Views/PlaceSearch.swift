//
//  PlaceSearch.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/3/24.
//

import SwiftUI

struct PlaceSearch: View {
  var placeholder: String
  var hasPendingQuery: Bool
  @Binding var places: [Place]?
  @Binding var queryText: String
  var canPickCurrentLocation: Bool
  var didDismissSearch: () -> Void
  var didSubmitSearch: () -> Void
  var didSelectPlace: (Place) -> Void

  @StateObject var preferences = Env.current.preferencesController.preferences
  @State private var scrollViewOffset: CGFloat = 0
  @EnvironmentObject var userLocationManager: UserLocationManager

  @MainActor
  var preferencesController: PreferencesController {
    Env.current.preferencesController
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        HStack {
          Image(systemName: "magnifyingglass").foregroundColor(
            .hw_searchFieldPlaceholderForeground)
          TextField(placeholder, text: $queryText)
            .submitLabel(.search)
            .dynamicTypeSize(.xxLarge)
            .onSubmit {
              didSubmitSearch()
            }
          if hasPendingQuery {
            ProgressView().padding(.trailing, 2)
          }
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

      // TODO: Only if there are search results and scrolled up a bit
      if scrollViewOffset < -5 {
        Divider()
      }
      ScrollView {
        VStack(spacing: 16) {
          if let places = places {
            if places.isEmpty && !hasPendingQuery {
              Text("No results. 😢")
            }
            PlaceList(
              places: $places,
              didSelectPlace: { place in
                Task {
                  await preferencesController.addSearch(text: queryText)
                }
                didSelectPlace(place)
              }
            )
          } else {
            if canPickCurrentLocation,
              let currentLocation = userLocationManager.mostRecentUserLocation
            {
              let currentPlace = Place(currentLocation: currentLocation)
              HStack {
                Button(action: { didSelectPlace(currentPlace) }) {
                  HStack {
                    Image(systemName: "location")
                    Text(currentPlace.name)
                  }
                }
                Spacer()
              }
            } else {
              Spacer(minLength: 16)
            }
            if !preferences.recentSearches.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text("Recent Searches").font(.headline)
                  Spacer()
                  Button(action: {
                    preferencesController.clear()
                  }) {
                    Text("Clear")
                  }
                }
                ForEach(Array(preferences.recentSearches.enumerated()), id: \.0) {
                  _, recentSearch in
                  HStack {
                    Button(action: { queryText = recentSearch }) {
                      Text(recentSearch)
                    }
                    Spacer()
                  }
                }
              }
            }
          }
          Spacer()
        }
        .padding()
        .overlay(
          GeometryReader { proxy in
            Color.clear
              .preference(
                key: ScrollViewOffsetPreferenceKey.self,
                value: proxy.frame(in: .named("scrollView")).minY)
          })
      }
      .coordinateSpace(name: "scrollView")
    }
    .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
      scrollViewOffset = value
    }
    .background(Color.hw_sheetBackground)
  }
}

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}
