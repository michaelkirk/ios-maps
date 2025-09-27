//
//  PlaceSearch.swift
//  maps.earth
//
//  Created by Michael Kirk on 5/3/24.
//

import SwiftUI

struct PlaceSearch<Content: View>: View {
  var placeholder: String = "placeholder"
  var hasPendingQuery: Bool = false
  @Binding var places: [Place]?
  @Binding var queryText: String
  var canPickCurrentLocation: Bool = false
  var didDismissSearch: () -> Void = {}
  var didSubmitSearch: () -> Void = {}
  var didSelectPlace: (Place) -> Void = { _ in }

  let slotContent: Content

  @State private var scrollViewOffset: CGFloat = 0
  @EnvironmentObject var userLocationManager: UserLocationManager
  @EnvironmentObject var preferences: Preferences

  init(
    placeholder: String = "placeholder",
    hasPendingQuery: Bool = false,
    places: Binding<[Place]?>,
    queryText: Binding<String>,
    canPickCurrentLocation: Bool = false,
    didDismissSearch: @escaping () -> Void = {},
    didSubmitSearch: @escaping () -> Void = {},
    didSelectPlace: @escaping (Place) -> Void = { _ in },
    @ViewBuilder slotContent: () -> Content = { EmptyView() }
  ) {

    self.placeholder = placeholder
    self.hasPendingQuery = hasPendingQuery
    self._places = places
    self._queryText = queryText
    self.canPickCurrentLocation = canPickCurrentLocation
    self.didDismissSearch = didDismissSearch
    self.didSubmitSearch = didSubmitSearch
    self.didSelectPlace = didSelectPlace
    self.slotContent = slotContent()
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
      slotContent
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
                  await preferences.addSearch(text: queryText)
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
            }
            if !preferences.recentSearches.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text("Recent Searches").font(.headline)
                  Spacer()
                  Button(action: {
                    Task { await preferences.clearSearch() }
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
    .presentationBackground(Color.hw_sheetBackground)
  }
}

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

#Preview("recent searches") {
  PlaceSearch(hasPendingQuery: true, places: .constant(nil), queryText: .constant("coffee"))
    .environmentObject(Preferences.forTesting())
}

#Preview("no recent searches") {
  PlaceSearch(hasPendingQuery: true, places: .constant(nil), queryText: .constant(""))
    .environmentObject(Preferences.forTesting(empty: ()))
}

#Preview("with accessory") {
  PlaceSearch(
    hasPendingQuery: true, places: .constant(nil), queryText: .constant("coffee"),
    slotContent: {
      HStack {
        Rectangle().fill(Color.hw_blue).frame(width: 20, height: 20)
        Text("Accessory View")
      }.padding()
        .border(.black)
    }
  ).environmentObject(Preferences.forTesting())
}
