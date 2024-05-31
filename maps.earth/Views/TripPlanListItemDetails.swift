//
//  TripPlanListItemDetails.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/5/24.
//

import SwiftUI

struct NonTransitPlanItem: View {
  var trip: Trip
  var onShowSteps: (() -> Void)

  var body: some View {
    VStack(alignment: .leading) {
      if let substantialRoadNames = trip.substantialStreetNames {
        Text(substantialRoadNames)
      }
      Text(trip.durationFormatted).font(.headline).dynamicTypeSize(.xxxLarge)
      Text(trip.distanceFormatted).font(.subheadline).foregroundColor(.secondary)
    }
    Spacer()
    TripButton("GO", action: onShowSteps)
  }
}

struct TransitPlanItem: View {
  var trip: Trip
  var onShowNavigation: (() -> Void)

  var body: some View {
    HStack(alignment: .top, spacing: 4) {
      VStack(alignment: .leading, spacing: 8) {
        Text(trip.timeSpanFormatted).font(.headline).dynamicTypeSize(.xxLarge)
        Text(routeEmojiSummary(trip: trip))
        TripButton("Steps", action: onShowNavigation)
      }
      Spacer()
      VStack(alignment: .trailing) {
        Text(trip.durationFormatted)
        Text(trip.distanceFormatted).font(.subheadline).foregroundColor(.secondary)
      }
    }.padding(.bottom, 8).padding(.trailing, 8)
  }
}

struct TripButton: View {
  var title: String
  var action: (() -> Void)

  init(_ title: String, action: @escaping () -> Void) {
    self.title = title
    self.action = action
  }

  var body: some View {
    Button(title, action: action)
      .fontWeight(.medium)
      .foregroundColor(.white)
      .padding(8)
      .background(.green)
      .cornerRadius(8)
      .scenePadding(.trailing)
  }
}

func routeEmojiSummary(trip: Trip) -> String {
  var output = ""
  var first = true
  for tripLeg in trip.legs {
    if !first {
      output += " → "
    }
    switch tripLeg.modeLeg {
    case .transit(let transitLeg):
      output += transitLeg.emojiRouteLabel
    case .nonTransit(_):
      output += tripLeg.mode.emoji
    }
    first = false
  }

  return output
}
