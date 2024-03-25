//
//  FrontPageSearch.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/15/24.
//

import SwiftUI

struct FrontPageSearch: View {
  var placeholder: String
  var hasPendingQuery: Bool
  @Binding var places: [Place]?
  @Binding var queryText: String
  @Binding var selectedPlace: Place?
  @ObservedObject var tripPlan: TripPlan
  var didDismissSearch: () -> Void
  var didSubmitSearch: () -> Void
  @Binding var placeDetailsDetent: PresentationDetent

  @StateObject var preferences = Env.current.preferencesController.preferences

  var preferencesController: PreferencesController {
    Env.current.preferencesController
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack {
        HStack {
          HStack {
            Image(systemName: "magnifyingglass").foregroundColor(
              .hw_searchFieldPlaceholderForeground)
            TextField("Where to?", text: $queryText)
              .submitLabel(.search)
              .dynamicTypeSize(.xxLarge)
              .onSubmit {
                didSubmitSearch()
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
        }

        let statusText =
          ({
            if hasPendingQuery {
              return "Looking... 🧐"
            } else if let places = places {
              return "\(places.count) Results"
            } else {
              return " "
            }
          })()
        Text(statusText).padding(.top, 8).bold()
      }.padding().padding(.top, 8)

      Divider()
      ScrollView {
        if let places = places {
          if places.isEmpty && !hasPendingQuery {
            Text("No results. 😢")
          }
          PlaceList(
            places: $places, selectedPlace: $selectedPlace, tripPlan: tripPlan,
            placeDetailsDetent: $placeDetailsDetent
          )
          .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 0))
          .onChange(of: selectedPlace) { newValue in
            if newValue != nil {
              let _ = print("selected place, so recording queryText: \(queryText)")
              Task {
                try await preferencesController.addSearch(text: queryText)
              }
            }
          }
        } else {
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
              ForEach(preferences.recentSearches.identifiable()) { recentSearch in
                let recentSearch = recentSearch.value
                HStack {
                  Button(action: { queryText = recentSearch }) {
                    Text(recentSearch)
                  }
                  Spacer()
                }
              }
            }.padding().padding(.top, 16)
          }
        }
        Spacer()
      }
    }
    // This padding is excessive, but works with/out notch and with sheet up/down.
    .padding(.top, 32)
    .background(Color.hw_sheetBackground)
  }
}

//#Preview {
//    FrontPageSearch()
//}
