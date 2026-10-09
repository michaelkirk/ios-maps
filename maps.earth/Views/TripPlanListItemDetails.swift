//
//  TripPlanListItemDetails.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/5/24.
//

import SwiftUI

struct NonTransitPlanItem: View {
  var trip: Trip
  var onGo: (() -> Void)

  /// e.g. "1.6 miles, 163 ft climb". Descent waits for the steps.
  private var distanceAndClimb: String {
    guard let climbMeters = trip.elevation?.totalClimbMeters, climbMeters > 0 else {
      return trip.distanceFormatted
    }
    return "\(trip.distanceFormatted), \(trip.formatFeetOrMeters(meters: climbMeters)) climb"
  }

  var body: some View {
    VStack(alignment: .leading) {
      if let substantialRoadNames = trip.substantialStreetNames {
        Text(substantialRoadNames)
      }
      Text(trip.durationFormatted).font(.headline).dynamicTypeSize(.xxxLarge)
      Text(distanceAndClimb).font(.subheadline).foregroundColor(.secondary)
      if let elevation = trip.elevation {
        // Only a glance here: tapping the trip opens its steps, where the chart can be scrubbed.
        ElevationChart(
          elevation: elevation, scrubFraction: .constant(nil), isInteractive: false
        ).frame(height: 40).padding(.vertical, 4)
      }
    }
    Spacer()
    GoButton(action: onGo)
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
            if firstTransitLeg.transitLeg?.realTime == true {
              Image(systemName: "dot.radiowaves.up.forward")
            }
            if let departureText = departureText(leg: firstTransitLeg) {
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

/// Starts navigation. Square, for a bigger target than a button sized to its title.
struct GoButton: View {
  var action: (() -> Void)

  var body: some View {
    Button(action: action) {
      Text("GO").frame(width: 56, height: 56)
    }
    .font(.system(size: 20, weight: .bold))
    .foregroundColor(.white)
    .background(.green)
    .cornerRadius(8)
    .scenePadding(.trailing)
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

func departureText(leg: TripLeg) -> AttributedString? {
  var output = AttributedString()
  let boldFont = Font.body.bold()

  if let startTime = formattedDurationUntilStart(start: leg.startTime, boldFont: boldFont) {
    output.append(startTime)
  }

  if let departFrom = formattedDepatureName(tripPlace: leg.fromPlace, boldFont: boldFont) {
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
  let tripPlan = FixtureData.walkTripPlan
  return NonTransitPlanItem(trip: tripPlan.selectedTrip!, onGo: {})
}

#Preview("biking, with grades") {
  let tripPlan = FixtureData.bikeGradeTripPlan
  return NonTransitPlanItem(trip: tripPlan.selectedTrip!, onGo: {})
}

#Preview("transit") {
  let trip = FixtureData.transitTripPlan.selectedTrip!
  return TransitPlanItem(trip: trip) {
    let _ = print("tapped")
  }
}
