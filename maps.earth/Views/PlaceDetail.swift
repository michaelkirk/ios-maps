//
//  PlaceDetail.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import CoreLocation
import Foundation
import SwiftUI

let addressFormatter = AddressFormatter()

struct PlaceDetailSheet: View {
  var place: Place
  var fromFavorite: Bool = false
  @ObservedObject var tripPlan: TripPlan
  @Binding var presentationDetent: PresentationDetent
  var onClose: () -> Void
  var didCompleteTrip: () -> Void

  @EnvironmentObject var userLocationManager: UserLocationManager
  @State private var detailedPlace: Place?
  @State private var isLoadingDetails = false

  var body: some View {
    let shareButton = ShareLink(item: UniversalLink.place(placeID: place.id).url) {
      // Copied from SheetButton. Using a SheetButton directly, looks fine, but
      // it seems like the button handler overrides the ShareLink tap behavior - no share sheet is presented.
      // So instead we just copy the styling.
      let width: CGFloat = 32
      return ZStack {
        Circle().frame(width: width - 2)
        Image(systemName: "square.and.arrow.up.circle.fill")
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: width, height: width)
          .tint(.hw_sheetCloseBackground)
      }.tint(Color.hw_sheetCloseForeground)
    }
    .padding(.trailing)
    return SheetContents(
      title: place.name,
      onClose: onClose,
      currentDetent: $presentationDetent,
      navigationAccessoryContent: { shareButton }
    ) {
      ScrollView {
        PlaceDetail(
          place: detailedPlace ?? place,
          tripPlan: tripPlan,
          isLoadingDetails: isLoadingDetails,
          didSelectNavigateTo: { place in
            tripPlan.navigateTo = place
            if let mostRecentUserLocation = self.userLocationManager
              .mostRecentUserLocation
            {
              tripPlan.navigateFrom = Place(currentLocation: mostRecentUserLocation)
            }
          },
          didCompleteTrip: didCompleteTrip
        )
      }
      // This is arguably useful.
      // Usually I just want to swipe down to get a better look at the map without closing out
      // of the place. If I actually want to dismiss, it's easy enough to hit the X
      .interactiveDismissDisabled(true)
    }
    .onAppear {
      if fromFavorite {
        fetchPlaceDetails()
      }
    }
  }

  private func fetchPlaceDetails() {
    guard !isLoadingDetails else { return }
    isLoadingDetails = true

    Task {
      do {
        let geocodeClient = GeocodeClient()
        if let fetchedPlace = try await geocodeClient.details(placeID: place.id) {
          await MainActor.run {
            detailedPlace = fetchedPlace
            isLoadingDetails = false
          }
        } else {
          await MainActor.run {
            isLoadingDetails = false
          }
        }
      } catch {
        print("Failed to fetch place details: \(error)")
        await MainActor.run {
          isLoadingDetails = false
        }
      }
    }
  }
}

struct PlaceDetail: View {
  var place: Place
  @ObservedObject var tripPlan: TripPlan
  var isLoadingDetails: Bool = false
  var didSelectNavigateTo: (Place) -> Void
  var didCompleteTrip: () -> Void
  @EnvironmentObject var preferences: Preferences

  @State private var showingCustomNameAlert = false
  @State private var customName = ""

  var body: some View {
    let isShowingDirections = Binding(
      get: { () -> Bool in
        let value = tripPlan.navigateTo != nil || tripPlan.navigateFrom != nil
        return value
      },
      set: { newValue in
      }
    )
    VStack(alignment: .leading) {
      HStack {
        Button(action: { didSelectNavigateTo(place) }) {
          Text("Directions")
        }
        .padding()
        .foregroundColor(.white)
        .background(Color.hw_blue)
        .cornerRadius(4)
        .sheet(isPresented: isShowingDirections) {
          TripPlanSheetContents(tripPlan: tripPlan, didCompleteTrip: didCompleteTrip)
            .interactiveDismissDisabled()
        }
        Spacer()
        if let favoritePlace = preferences.favoritePlaces.first(where: { $0.placeId == place.id }) {
          Button(action: {
            Task {
              await preferences.removeFavoritePlace(place: place)
            }
          }) {
            HStack {
              favoritePlace.saveButtonIcon
              Text("Save")
            }
          }
          .padding()
          .foregroundColor(.white)
          .background(favoritePlace.iconColor)
          .cornerRadius(4)
        } else {
          Button(action: {
            Task {
              await preferences.addFavoritePlace(place: place, as: .other(place.name))
            }
          }) {
            HStack {
              Image(systemName: "star")
              Text("Save")
            }
          }
          .padding()
          .foregroundColor(.white)
          .background(Color.hw_blue)
          .cornerRadius(4)
          .contextMenu {
            Button(action: {
              Task {
                await preferences.addFavoritePlace(place: place, as: .home)
              }
            }) {
              Label("Save as Home", systemImage: "house.fill")
            }

            Button(action: {
              Task {
                await preferences.addFavoritePlace(place: place, as: .work)
              }
            }) {
              Label("Save as Work", systemImage: "briefcase.fill")
            }

            Button(action: {
              customName = place.name
              showingCustomNameAlert = true
            }) {
              Label("Save as other...", systemImage: "mappin")
            }
          }
        }
      }.scenePadding(.bottom)

      Text("Details").font(.title3).bold()
      VStack(alignment: .leading) {
        if isLoadingDetails {
          HStack {
            ProgressView()
              .scaleEffect(0.8)
            Text("Loading details...")
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 8)
        } else {
          if let phoneNumber = place.phoneNumber {
            let readableFormat = phoneNumberKit.format(phoneNumber, toType: .national)
            let e164 = phoneNumberKit.format(phoneNumber, toType: .e164)
            if let phoneURL = URL(string: "tel://\(e164)") {
              Text("Phone").foregroundColor(.secondary)
              Link(readableFormat, destination: phoneURL)
              Divider()
            }
          }
          if let websiteURL = place.websiteURL {
            Text("Website").foregroundColor(.secondary)
            Link(websiteURL.absoluteString, destination: websiteURL)
            Divider()
          }
          if let formattedAddress = addressFormatter.format(place: place, includeCountry: true) {
            Text("Address").foregroundColor(.secondary)
            Text(formattedAddress)
          }
        }
      }.padding().background(Color.white).cornerRadius(8)
    }.scenePadding(.leading)
      .scenePadding(.trailing)
      .alert("Save as Favorite", isPresented: $showingCustomNameAlert) {
        TextField("Name", text: $customName)
        Button("Save") {
          Task {
            await preferences.addFavoritePlace(place: place, as: .other(customName))
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Enter a custom name for this favorite place.")
      }
  }
}

#Preview("Place Sheet") {
  Text("").sheet(isPresented: .constant(true)) {
    PlaceDetailSheet(
      place: FixtureData.places[.zeitgeist], fromFavorite: false, tripPlan: TripPlan(),
      presentationDetent: .constant(.medium), onClose: {}, didCompleteTrip: {})
  }
}
