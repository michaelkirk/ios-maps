//
//  MultiModalTripDetails.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/14/24.
//

import SwiftUI

struct TripDiagram {
  enum Element {
    case node(Node)
    case edge(TripLeg, badge: LegBadge)
  }

  enum Node {
    case origin(from: Place, departureTime: Date)
    case stop(departingLeg: TripLeg)
    case destination(to: Place, arrivalTime: Date)

    var lngLat: LngLat {
      switch self {
      case .origin(from: let place, departureTime: _): place.location
      case .stop(let leg): leg.fromPlace.location
      case .destination(to: let place, arrivalTime: _): place.location
      }
    }
  }

  let trip: Trip
  var elements: [Element]
  init(trip: Trip) {
    self.trip = trip
    var elements: [Element] = []
    let firstLeg = trip.legs[0]
    elements.append(
      .node(.origin(from: trip.from, departureTime: firstLeg.startTime))
    )
    let badges = TripGroup(trips: [trip]).legBadges
    for (legIdx, leg) in trip.legs.enumerated() {
      if legIdx > 0 {
        elements.append(.node(.stop(departingLeg: leg)))
      }
      elements.append(.edge(leg, badge: badges[legIdx]))
    }
    elements.append(
      .node(.destination(to: trip.to, arrivalTime: trip.legs.last!.endTime))
    )

    self.elements = elements
  }
}

extension MultiModalTripDetails {
  init(trip: Trip, onFocus: @escaping (TripPlan.FocusedStep) -> Void) {
    self.init(tripDiagram: TripDiagram(trip: trip), onFocus: onFocus)
  }
}

extension TripDiagram.Element {
  /// Where the map zooms to when the rider taps this step of `trip`, and what it says there.
  func focusedStep(in trip: Trip) -> TripPlan.FocusedStep {
    switch self {
    case .node(.origin(from: _, departureTime: _)): trip.legs[0].focusedStep
    case .node(.stop(let leg)), .edge(let leg, badge: _): leg.focusedStep
    case .node(.destination(let place, arrivalTime: _)):
      TripPlan.FocusedStep(location: place.location, description: "Arrive at your destination")
    }
  }
}

struct MultiModalTripDetails: View {
  var tripDiagram: TripDiagram
  var onFocus: (TripPlan.FocusedStep) -> Void

  var trip: Trip {
    tripDiagram.trip
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("\(trip.durationFormatted) (\(trip.distanceFormatted))").scenePadding(.leading).hwText(
        .heading)
      ScrollView {
        Grid(alignment: .trailing, verticalSpacing: 0) {
          ForEach(Array(tripDiagram.elements.enumerated()), id: \.0) { _, step in
            GridRow(alignment: .top) {
              switch step {
              case .node(.origin(from: let place, departureTime: let departureTime)):
                StepTime(time: departureTime, realTime: trip.legs[0].isRealTime)
                  .padding(.vertical, 4)
                NodeGlyph(systemName: "mappin.circle")
                HStack {
                  Text("Depart: \(place.name)")
                  Spacer()
                }
                .padding(.vertical, 4)
              case .node(.stop(let leg)):
                StepTime(time: leg.startTime, realTime: leg.isRealTime)
                  .padding(.vertical, 4)
                VStack {
                  NodeGlyph(systemName: "circle").foregroundColor(.secondary)
                  Spacer().frame(minWidth: 4, maxWidth: 4, maxHeight: .infinity)
                    .background(leg.activeLineColor)
                    .frame(width: timelineWidth)
                }
                HStack {
                  Text(leg.fromPlace.name ?? "")
                  Spacer()
                }.padding(.top, 4)
              case .node(.destination(to: let place, arrivalTime: let arrivalTime)):
                StepTime(time: arrivalTime, realTime: trip.legs[trip.legs.count - 1].isRealTime)
                  .padding(.vertical, 4)
                NodeGlyph(systemName: "flag.checkered.circle")
                HStack {
                  Text("Arrive: \(place.name)")
                  Spacer()
                }
                .padding(.vertical, 4)

              case .edge(let leg, let badge):
                RoutePill(badge: badge).padding(.top, 4)
                Spacer().frame(minWidth: 4, maxWidth: 4, maxHeight: .infinity)
                  .padding(.vertical, 30)
                  .background(leg.activeLineColor)
                  .frame(width: timelineWidth)
                HStack {
                  legDescription(leg).padding(.top, 4)
                  Spacer()
                }
              }
            }
            .contentShape(Rectangle())
            .onTapGesture { onFocus(step.focusedStep(in: trip)) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows this step on the map")
            .accessibilityAction { onFocus(step.focusedStep(in: trip)) }
          }
        }.padding()
      }
    }
  }
}

extension MultiModalTripDetails {
  /// What riding or walking a leg involves, beyond the pill beside it: "toward Lynnwood" over
  /// "25 min · 9 stops", or for a walk, how far.
  @ViewBuilder
  func legDescription(_ leg: TripLeg) -> some View {
    if let transitLeg = leg.transitLeg {
      let facts = [
        "\(leg.durationMinutes) min",
        leg.stopsRidden.map { $0 == 1 ? "1 stop" : "\($0) stops" },
      ].compactMap { $0 }.joined(separator: " · ")
      VStack(alignment: .leading) {
        if let headsign = transitLeg.headsign {
          Text("toward \(headsign)")
        }
        Text(facts).foregroundStyle(.secondary)
      }
    } else {
      Text(trip.legDistanceFormatted(meters: leg.geometry.distance() ?? 0))
    }
  }
}

/// When a step happens, marked when the time comes from live data.
struct StepTime: View {
  var time: Date
  var realTime: Bool

  var body: some View {
    HStack(spacing: 2) {
      if realTime {
        Image(systemName: "dot.radiowaves.up.forward").font(.caption)
          .accessibilityLabel("Live")
      }
      Text(time.formatted(date: .omitted, time: .shortened))
    }
  }
}

let timelineWidth: CGFloat = 24
struct NodeGlyph: View {
  var systemName: String
  var body: some View {
    Image(systemName: systemName).resizable().scaledToFit().frame(
      width: timelineWidth, height: timelineWidth
    )
    .padding(.vertical, 4)
  }
}

struct MultiModalTripDetailsSheetContents: View {
  var trip: Trip
  @Binding var currentDetent: PresentationDetent
  var onFocus: (TripPlan.FocusedStep) -> Void
  var onClose: () -> Void

  var body: some View {
    SheetContents(title: "Steps", onClose: onClose, currentDetent: $currentDetent) {
      MultiModalTripDetails(trip: trip, onFocus: onFocus)
    }
  }
}

#Preview("Bus Trip Details") {
  let trip = FixtureData.transitTrips[0]
  return Text("").sheet(isPresented: .constant(true)) {
    MultiModalTripDetailsSheetContents(
      trip: trip, currentDetent: .constant(initialDetentHeight), onFocus: { _ in }, onClose: {})
  }
}
