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
  var group: TripGroup
  /// Whichever of the group's departures is picked.
  var trip: Trip
  var onSelect: ((Trip) -> Void)
  /// The rider tapped the pill of the leg at this index.
  var onFocusLeg: ((Int) -> Void)
  var onShowNavigation: (() -> Void)

  var body: some View {
    HStack(alignment: .top, spacing: Space.xs) {
      VStack(alignment: .leading, spacing: Space.s) {
        Text(trip.timeSpanFormatted).hwText(.figure)
        LegPills(group: group, trip: trip, onFocusLeg: onFocusLeg)
        // Kept current, so "in 3 min" stays true and moves on as departures leave.
        TimelineView(.periodic(from: .now, by: 30)) { context in
          if let departureText = departureText(group: group, trip: trip, now: context.date) {
            Text(departureText)
          }
        }
        if group.trips.count > 1 {
          DepartureChips(group: group, selected: trip, onSelect: onSelect)
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

/// A pill for each leg worth one, in order.
struct LegPills: View {
  var group: TripGroup
  var trip: Trip
  var onFocusLeg: ((Int) -> Void)

  var body: some View {
    // Room above for the badges hanging off a wrapped row's pills.
    FlowLayout(spacing: Space.s) {
      ForEach(Array(group.listedLegs.enumerated()), id: \.element.legIdx) { listedIdx, listed in
        HStack(spacing: 2) {
          if listedIdx > 0 {
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
              .foregroundStyle(.secondary)
              // Clear of the badges hanging off the previous pill's corner.
              .padding(.leading, 4)
          }
          Button {
            onFocusLeg(listed.legIdx)
          } label: {
            RoutePill(badge: listed.badge, realTime: trip.legs[listed.legIdx].isRealTime)
          }
          // Its own target, rather than the row's.
          .buttonStyle(.borderless)
        }
      }
    }.padding(.top, 4)
  }
}

/// A leg of a trip at a glance: the routes it rides, each in its own colors, then the kind of
/// vehicle - or how long the walker or cyclist takes getting themselves there.
struct RoutePill: View {
  var badge: LegBadge
  /// Whether the leg's times come from live data.
  var realTime = false

  private static let height: CGFloat = 24
  private static let shape = RoundedRectangle(cornerRadius: 6)

  var body: some View {
    pill.overlay(alignment: .topTrailing) {
      if realTime {
        LiveBadge().offset(x: 7, y: -6)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityText)
  }

  /// e.g. "🚍 10 / 12", "🚶‍♀️ 4 min"
  private var accessibilityText: String {
    switch badge {
    case .ride(let emoji, let routes):
      "\(emoji) \(routes.map(\.label).joined(separator: " / "))"
    case .selfPowered(let emoji, let minutes):
      "\(emoji) \(minutes) min"
    }
  }

  @ViewBuilder
  private var pill: some View {
    switch badge {
    case .ride(let emoji, let routes):
      HStack(spacing: 0) {
        ForEach(routes.indices, id: \.self) { idx in
          if idx > 0 {
            slash(between: routes[idx - 1], and: routes[idx])
          }
          Text(routes[idx].label)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(routes[idx].textColor.color)
            .padding(.leading, idx == 0 ? 6 : 3)
            .padding(.trailing, idx == routes.count - 1 ? 6 : 3)
            .frame(maxHeight: .infinity)
            .background(routes[idx].color.color)
        }
        // Behind the vehicle, continuing the route beside it.
        vehicleDisc(emoji).frame(maxHeight: .infinity)
          .background((routes.last?.color ?? .activeRoute).color)
      }
      .frame(height: Self.height)
      .clipShape(Self.shape)
      .overlay(
        Self.shape.strokeBorder((routes.first?.color ?? .activeRoute).color, lineWidth: 1.5))
    case .selfPowered(let emoji, let minutes):
      HStack(spacing: 0) {
        Text("\(minutes)").font(.system(size: 13)).foregroundStyle(.black)
          .padding(.leading, 6).padding(.trailing, 4)
        vehicleDisc(emoji)
      }
      .frame(height: Self.height)
      .background(Color(gray: 0.894), in: Self.shape)
    }
  }

  /// The "/" between merged routes, straddling the seam between their colors.
  private func slash(between left: RouteBadge, and right: RouteBadge) -> some View {
    Text("/")
      .font(.system(size: 15))
      .foregroundStyle(left.textColor.color.opacity(0.85))
      .frame(maxHeight: .infinity)
      .background(
        LinearGradient(
          stops: [
            .init(color: left.color.color, location: 0.5),
            .init(color: right.color.color, location: 0.5),
          ], startPoint: .leading, endPoint: .trailing))
  }

  /// Like the vehicle markers on the map - a white disc, ringed by the pill's color - but flat.
  private func vehicleDisc(_ emoji: String) -> some View {
    Text(emoji).font(.system(size: 11))
      .frame(width: 18, height: 18)
      .background(.white, in: Circle())
      .padding(.leading, 1).padding(.trailing, 3)
  }
}

/// Marks a leg whose times come from live data, tucked onto its pill's corner.
struct LiveBadge: View {
  var body: some View {
    Image(systemName: "dot.radiowaves.up.forward")
      .font(.system(size: 9.5, weight: .semibold))
      .foregroundStyle(Color.hw_darkGray)
      // The glyph's weight sits in its lower left corner, so centered in a disc it looks low and
      // left.
      .offset(x: 0.5, y: -0.5)
      .frame(width: 14, height: 14)
      .background(.white, in: Circle())
      .overlay(Circle().strokeBorder(.black.opacity(0.35), lineWidth: 1))
  }
}

/// Each departure of a trip, to pick between.
struct DepartureChips: View {
  var group: TripGroup
  var selected: Trip
  var onSelect: ((Trip) -> Void)

  var body: some View {
    // Wrapped rather than scrolled: a scroll view would hide each chip from accessibility inside
    // the row's button.
    FlowLayout(spacing: Space.xs) {
      ForEach(group.trips) { trip in
        let isSelected = trip == selected
        Button(trip.departureTimeFormatted) { onSelect(trip) }
          .hwText(.label)
          .foregroundColor(isSelected ? .white : .primary)
          .padding(.horizontal, 10).padding(.vertical, 5)
          .background(isSelected ? Color.hw_blue : .clear, in: Capsule())
          .overlay(Capsule().stroke(isSelected ? Color.clear : Color.secondary, lineWidth: 1))
          // Its own target, rather than the row's.
          .buttonStyle(.borderless)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }.padding(1)
  }
}

/// Lays its subviews out in rows, wrapping to a new row when one fills.
struct FlowLayout: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let frames = frames(for: subviews, maxWidth: proposal.width ?? .infinity)
    return CGSize(
      width: frames.map(\.maxX).max() ?? 0, height: frames.map(\.maxY).max() ?? 0)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    for (subview, frame) in zip(subviews, frames(for: subviews, maxWidth: bounds.width)) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        proposal: ProposedViewSize(frame.size))
    }
  }

  private func frames(for subviews: Subviews, maxWidth: CGFloat) -> [CGRect] {
    var frames: [CGRect] = []
    var origin = CGPoint.zero
    var rowHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if origin.x > 0 && origin.x + size.width > maxWidth {
        origin = CGPoint(x: 0, y: origin.y + rowHeight + spacing)
        rowHeight = 0
      }
      frames.append(CGRect(origin: origin, size: size))
      origin.x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    return frames
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

/// e.g. "in **3 min & 23 min** from **Symphony**": the group's next two departures, or how long
/// ago `trip` left once none are ahead.
func departureText(group: TripGroup, trip: Trip, now: Date) -> AttributedString? {
  guard let leg = trip.firstTransitLeg else {
    return nil
  }
  let upcoming = group.trips.compactMap { $0.firstTransitLeg?.startTime }
    .filter { $0 >= now }.prefix(2)
    .map { shortDuration(from: now, to: $0) }

  var output = AttributedString()
  if upcoming.isEmpty {
    output.append(bold(shortDuration(from: leg.startTime, to: now)))
    output.append(AttributedString(" ago"))
  } else {
    output.append(AttributedString("in "))
    output.append(bold(upcoming.joined(separator: " & ")))
  }
  if let departFrom = formattedDepatureName(tripPlace: leg.fromPlace, boldFont: .body.bold()) {
    output.append(AttributedString(" "))
    output.append(departFrom)
  }
  return output
}

private func bold(_ text: String) -> AttributedString {
  var output = AttributedString(text)
  output.font = UIFont.boldSystemFont(ofSize: 16)
  return output
}

/// e.g. "3 min", "1 hr 5 min", or "40 sec" under a minute rather than "0 min".
func shortDuration(from: Date, to: Date) -> String {
  let formatter = DateComponentsFormatter()
  formatter.unitsStyle = .short
  formatter.allowedUnits = to.timeIntervalSince(from) < 60 ? [.second] : [.hour, .minute]
  return formatter.string(from: from, to: to) ?? ""
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
  let group = TripGroup.group(FixtureData.transitTrips)[0]
  return TransitPlanItem(group: group, trip: trip, onSelect: { _ in }, onFocusLeg: { _ in }) {
    let _ = print("tapped")
  }
}
