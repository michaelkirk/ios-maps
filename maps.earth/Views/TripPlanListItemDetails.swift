//
//  TripPlanListItemDetails.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/5/24.
//

import SwiftUI

struct TripPlanListItemDetails: View {
  var trip: Trip
  @Binding
  var tripPlanMode: TravelMode
  var onShowSteps: (() -> Void)

  var body: some View {
    HStack {
      if tripPlanMode == .transit {
        TransitPlanItem(trip: trip, onShowSteps: onShowSteps)
      } else {
        NonTransitPlanItem(trip: trip, onShowSteps: onShowSteps)
      }
    }.padding(.top, 8).padding(.bottom, 8)
  }
}

struct NonTransitPlanItem: View {
  var trip: Trip
  var onShowSteps: (() -> Void)
  var body: some View {
    VStack(alignment: .leading) {
      Text(trip.durationFormatted).font(.headline).dynamicTypeSize(.xxxLarge)
      Text(trip.distanceFormatted).font(.subheadline).foregroundColor(.secondary)
    }
    Spacer()
    Button("Steps") {
      onShowSteps()
    }
    .fontWeight(.medium)
    .foregroundColor(.white)
    .padding(8)
    .background(.green)
    .cornerRadius(8)
    .scenePadding(.trailing)
  }
}

struct TransitPlanItem: View {
  var trip: Trip
  var onShowSteps: (() -> Void)
  var body: some View {
    HStack(spacing: 4) {
      VStack(alignment: .leading, spacing: 8) {
        Text(trip.timeSpanFormatted).font(.headline).dynamicTypeSize(.xxLarge)
        Text(routeEmojiSummary(trip: trip))
      }
      Spacer()
      VStack(alignment: .trailing) {
        Text(trip.durationFormatted)
        Text(trip.distanceFormatted).font(.subheadline)
      }
    }.padding(.bottom, 8).padding(.trailing, 8)
  }
}

struct IdentifiableValue<T>: Identifiable {
  let id: Int
  let value: T
}

extension Collection {
  func identifiable() -> [IdentifiableValue<Self.Element>] {
    Array(self.enumerated()).map { IdentifiableValue(id: $0.offset, value: $0.element) }
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
      output += "\(transitLeg.mode.emoji) \(transitLeg.routeSummaryName)"
    case .nonTransit(_):
      // eventually we'll support bike+bus
      output += TravelMode.walk.emoji
    }
    first = false
  }

  return output
}