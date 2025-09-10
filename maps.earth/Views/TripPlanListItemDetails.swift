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
      if let elevationProfile = trip.elevationProfile {
        VStack(alignment: .leading, spacing: 0) {
          HStack {
            Text("↑ \(elevationProfile.formattedTotalClimb)").font(.caption).foregroundStyle(.red)
            Text("↓ \(elevationProfile.formattedTotalFall)").font(.caption).foregroundStyle(.green)
          }
          GeometryReader { reader in
            ElevationChart(
              elevations: elevationProfile.raw.elevation, width: reader.size.width - 20)
          }.frame(idealWidth: .infinity, idealHeight: 26)
        }
      }
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
        if let firstTransitLeg = trip.firstTransitLeg {
          HStack {
            if firstTransitLeg.realTime {
              Image(systemName: "dot.radiowaves.up.forward")
            }
            if let departureText = departureText(transitLeg: firstTransitLeg) {
              Text(departureText)
            }
          }
        }
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

func departureText(transitLeg: TransitLeg) -> AttributedString? {
  var output = AttributedString()
  let boldFont = Font.body.bold()

  if let startTime = formattedDurationUntilStart(start: transitLeg.startDate, boldFont: boldFont) {
    output.append(startTime)
  }

  if let departFrom = formattedDepatureName(tripPlace: transitLeg.from, boldFont: boldFont) {
    if !output.characters.isEmpty {
      output.append(AttributedString(" "))
    }
    output.append(departFrom)
  }

  return output
}

func formattedDurationUntilStart(start: Date, now: Date = .now, boldFont: Font) -> AttributedString?
{
  var output = AttributedString()
  if start > now {
    output.append(AttributedString("in "))
    var duration = AttributedString(formatDuration(from: now, to: start))
    duration.font = UIFont.boldSystemFont(ofSize: 16)
    output.append(duration)
  } else {
    var duration = AttributedString(formatDuration(from: start, to: now))
    duration.font = UIFont.boldSystemFont(ofSize: 16)
    output.append(duration)
    output.append(AttributedString(" ago"))
  }
  if output.characters.count > 0 {
    return output
  } else {
    return nil
  }
}

func formattedDepatureName(tripPlace: TripPlace, boldFont: Font) -> AttributedString? {
  guard let name = tripPlace.name else {
    return nil
  }
  var output = AttributedString("from ")
  var place = AttributedString(name)
  place.font = boldFont
  output.append(place)
  return output
}

#Preview("walking") {
  let trip = FixtureData.walkTripPlan.selectedTrip!
  return NonTransitPlanItem(trip: trip) {
    let _ = print("tapped")
  }
}

#Preview("transit") {
  let trip = FixtureData.transitTripPlan.selectedTrip!
  return TransitPlanItem(trip: trip) {
    let _ = print("tapped")
  }
}
