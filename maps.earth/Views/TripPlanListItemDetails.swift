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
      Text(trip.durationFormatted).hwText(.figure)
      Text(distanceAndClimb).hwText(.secondary)
      if !trip.routePreferences.isEmpty {
        RoutePreferenceBadges(preferences: trip.routePreferences)
      }
      if let elevation = trip.elevation {
        // Only a glance here: its steps are where the chart can be scrubbed.
        ElevationChart(
          elevation: elevation, scrubFraction: .constant(nil), isInteractive: false
        ).frame(height: 40).padding(.vertical, 4)
      }
    }
    Spacer()
    GoButton(action: onGo)
  }
}

/// Says which cycling objectives a route is the best answer to - it may well be the best at several.
struct RoutePreferenceBadges: View {
  var preferences: [BikeRoutePreference]

  var body: some View {
    HStack(spacing: Space.xs) {
      ForEach(preferences, id: \.self) { preference in
        HStack(spacing: 3) {
          Text(preference.emoji)
          Text(preference.label)
        }
        .foregroundStyle(preference.ink).hwText(.label)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(preference.tint, in: Capsule())
      }
    }
  }
}

extension BikeRoutePreference {
  var label: String {
    switch self {
    case .quieter: "Comfier"
    case .faster: "Faster"
    }
  }

  var emoji: String {
    switch self {
    case .quieter: "🦦"
    case .faster: "⚡"
    }
  }

  var tint: Color {
    switch self {
    case .quieter: .hw_teal100
    case .faster: .hw_amber100
    }
  }

  var ink: Color {
    switch self {
    case .quieter: .hw_teal700
    case .faster: .hw_amber700
    }
  }
}

struct TransitPlanItem: View {
  var trip: Trip
  var onShowNavigation: (() -> Void)

  var body: some View {
    HStack(alignment: .top, spacing: Space.xs) {
      VStack(alignment: .leading, spacing: Space.s) {
        Text(trip.timeSpanFormatted).hwText(.figure)
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
        Text(trip.distanceFormatted).hwText(.secondary)
      }
    }.padding(.bottom, Space.s).padding(.trailing, Space.s)
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
    .background(Color.hw_go)
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
      .background(Color.hw_go)
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

#Preview("bicycle") {
  let tripPlan = FixtureData.bikeTripPlan
  return NonTransitPlanItem(trip: tripPlan.selectedTrip!, onGo: {})
}

#Preview("transit") {
  let trip = FixtureData.transitTripPlan.selectedTrip!
  return TransitPlanItem(trip: trip) {
    let _ = print("tapped")
  }
}
