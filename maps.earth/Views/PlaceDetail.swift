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
  @ObservedObject var tripPlan: TripPlan
  @Binding var presentationDetent: PresentationDetent
  var onClose: () -> Void

  @EnvironmentObject var userLocationManager: UserLocationManager

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
          place: place, tripPlan: tripPlan,
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

struct PlaceDetail: View {
  var place: Place
  @ObservedObject var tripPlan: TripPlan
  var didSelectNavigateTo: (Place) -> Void

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
        .background(.blue)
        .cornerRadius(4)
        .sheet(isPresented: isShowingDirections) {
          TripPlanSheetContents(tripPlan: tripPlan)
            .interactiveDismissDisabled()
        }
        Spacer()
      }.scenePadding(.bottom)

      Text("Details").font(.title3).bold()
      VStack(alignment: .leading) {
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
      }.padding().background(Color.white).cornerRadius(8)
    }.scenePadding(.leading)
      .scenePadding(.trailing)
  }
}

#Preview("Place Sheet") {
  Text("").sheet(isPresented: .constant(true)) {
    PlaceDetailSheet(
      place: FixtureData.places[.zeitgeist], tripPlan: TripPlan(),
      presentationDetent: .constant(.medium), onClose: {})
  }
}
