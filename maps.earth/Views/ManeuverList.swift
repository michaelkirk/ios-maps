//
//  ManeuverList.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/14/24.
//

import SwiftUI

struct ManeuverElement: Identifiable {
  let maneuver: Maneuver
  let id: Int

  init(maneuver: Maneuver, id: Int) {
    self.maneuver = maneuver
    self.id = id
  }
}

func image(maneuverType: ManeuverType) -> Image? {
  guard let name = imageName(maneuverType: maneuverType) else {
    return nil
  }
  return Image(systemName: name)
}

func imageName(maneuverType: ManeuverType) -> String? {
  switch maneuverType {
  case .none:
    nil
  case .start:
    "mappin.circle"
  case .startRight:
    "mappin.circle"
  case .startLeft:
    "mappin.circle"
  case .destination:
    "flag.checkered.circle"
  case .destinationRight:
    "flag.checkered.circle"
  case .destinationLeft:
    "flag.checkered.circle"
  case .becomes:
    "info.circle"
  case .continue:
    "arrow.up"
  case .slightRight:
    "arrow.up.right"
  case .right:
    "arrow.turn.up.right"
  case .sharpRight:
    "arrow.turn.up.right"
  case .uturnRight:
    "arrow.uturn.right"
  case .uturnLeft:
    "arrow.uturn.left"
  case .sharpLeft:
    "arrow.turn.up.left"
  case .left:
    "arrow.turn.up.left"
  case .slightLeft:
    "arrow.up.left"
  case .rampStraight:
    "arrow.up"
  case .rampRight:
    "arrow.up.right"
  case .rampLeft:
    "arrow.up.left"
  case .exitRight:
    "arrow.up.right"
  case .exitLeft:
    "arrow.up.left"
  case .stayStraight:
    "arrow.up"
  case .stayRight:
    "arrow.up.right"
  case .stayLeft:
    "arrow.up.left"
  case .merge:
    "arrow.merge"
  case .roundaboutEnter:
    "arrow.triangle.2.circlepath"
  case .roundaboutExit:
    "arrow.triangle.2.circlepath"
  case .ferryEnter:
    "ferry"
  case .ferryExit:
    "ferry"
  case .transit:
    "info.circle"
  case .transitTransfer:
    "info.circle"
  case .transitRemainOn:
    "info.circle"
  case .transitConnectionStart:
    "info.circle"
  case .transitConnectionTransfer:
    "info.circle"
  case .transitConnectionDestination:
    "info.circle"
  case .postTransitConnectionDestination:
    "info.circle"
  case .mergeRight:
    "arrow.merge"
  case .mergeLeft:
    "arrow.merge"
  case .elevatorEnter:
    "square.and.arrow.down"
  case .stepsEnter:
    "stairs"
  case .escalatorEnter:
    "stairs"
  case .buildingEnter:
    "door.left.hand.open"
  case .buildingExit:
    "door.right.hand.open"
  }
}

struct ManeuverList: View {
  var trip: Trip
  @ObservedObject var tripPlan: TripPlan
  var maneuvers: [Maneuver]
  var onGo: (() -> Void)?
  @State private var isShowingClimbs = false

  var body: some View {
    let maneuversElements = maneuvers.enumerated().map {
      ManeuverElement(maneuver: $1, id: $0)
    }

    VStack(alignment: .leading) {
      HStack {
        Text("\(trip.durationFormatted) (\(trip.distanceFormatted))").hwText(.heading)
        Spacer()
        if let onGo {
          GoButton(action: onGo)
        }
      }.scenePadding(.leading)
      List {
        if let elevation = trip.elevation {
          ElevationChart(
            elevation: elevation, scrubFraction: $tripPlan.scrubFraction,
            onSelectClimb: { tripPlan.select(climb: $0, of: elevation) }
          ).frame(height: 100)
          steepSections(elevation)
        }
        ForEach(maneuversElements) { el in
          let maneuver = el.maneuver
          Button {
            tripPlan.focusedStep = TripPlan.FocusedStep(location: maneuver.startPoint.lngLat)
          } label: {
            maneuverRow(maneuver)
          }.buttonStyle(.plain)
        }
      }.hwListStyle()
    }
  }

  private func maneuverRow(_ maneuver: Maneuver) -> some View {
    HStack(spacing: Space.l) {
      image(maneuverType: maneuver.type).imageScale(.large)
      VStack(alignment: .leading) {
        if let instruction = maneuver.instruction {
          Text(instruction)
        }
        if let verbalPostTransitionInstruction = maneuver.verbalPostTransitionInstruction {
          Text(verbalPostTransitionInstruction).hwText(.secondary)
        }
      }
      Spacer()
    }.contentShape(Rectangle())
  }

  /// The leg's steep stretches, collapsed under how far it climbs and descends in all.
  @ViewBuilder
  private func steepSections(_ elevation: LegElevation) -> some View {
    let header = HStack(spacing: 4) {
      Text("Hills:")
      ElevationTotals(trip: trip, elevation: elevation)
    }.hwText(.secondary)
    if elevation.steepSections.isEmpty {
      header
    } else {
      DisclosureGroup(isExpanded: $isShowingClimbs) {
        ForEach(elevation.steepSections, id: \.self) { section in
          Button {
            tripPlan.select(climb: section, of: elevation)
          } label: {
            SteepSectionRow(trip: trip, section: section)
          }.buttonStyle(.plain)
        }
      } label: {
        header
      }
    }
  }
}

/// e.g. "↗ 9%  200 ft on E Thomas St, steepest 12%"
struct SteepSectionRow: View {
  let trip: Trip
  let section: SteepSection

  var body: some View {
    HStack(spacing: Space.m) {
      Text("\(section.isClimb ? "↗" : "↘") \(section.percent)%").bold()
        .foregroundStyle(section.isClimb ? Color.hw_amber700 : Color.hw_teal700)
      Text(description)
      Spacer()
    }.contentShape(Rectangle())
  }

  private var description: String {
    let length = trip.formatFeetOrMeters(meters: section.endMeters - section.startMeters)
    let steepest = "\(Int((abs(section.maxGrade) * 100).rounded()))%"
    if let streetName = section.streetName {
      return "\(length) on \(streetName), steepest \(steepest)"
    } else {
      return "\(length), steepest \(steepest)"
    }
  }
}

struct ManeuverListSheetContents: View {
  var trip: Trip
  @ObservedObject var tripPlan: TripPlan
  var maneuvers: [Maneuver]
  @Binding var currentDetent: PresentationDetent
  var onGo: (() -> Void)?
  var onClose: () -> Void

  var body: some View {
    // No taller than medium, so the map stays in view while scrolling through the steps.
    SheetContents(
      title: "Steps", onClose: onClose, presentationDetents: [.medium, minDetentHeight],
      currentDetent: $currentDetent
    ) {
      ManeuverList(trip: trip, tripPlan: tripPlan, maneuvers: maneuvers, onGo: onGo)
    }
  }
}

#Preview("Walking Maneuvers") {
  let trip = FixtureData.walkTrips[0]
  guard case .nonTransit(let nonTransitLeg) = trip.legs[0].modeLeg else {
    fatalError("unexpected legs for trip")
  }

  return Text("").sheet(isPresented: .constant(true)) {
    ManeuverListSheetContents(
      trip: trip, tripPlan: FixtureData.walkTripPlan, maneuvers: nonTransitLeg.maneuvers,
      currentDetent: .constant(initialDetentHeight), onGo: {}, onClose: {})
  }
}

#Preview("All Maneuvers") {
  let trip = FixtureData.walkTrips[0]
  let maneuvers = ManeuverType.allCases.map { maneuver in
    Maneuver(
      instruction: "maneuver: \(maneuver)", type: maneuver,
      verbalPostTransitionInstruction: "Go 123 miles.",
      startPoint: LonLatPair(LngLat(lng: -122.3, lat: 47.6)))
  }

  return Text("").sheet(isPresented: .constant(true)) {
    ManeuverListSheetContents(
      trip: trip, tripPlan: FixtureData.walkTripPlan, maneuvers: maneuvers,
      currentDetent: .constant(initialDetentHeight), onGo: {}, onClose: {})
  }
}

#Preview("Biking, with grades") {
  let tripPlan = FixtureData.bikeGradeTripPlan
  let trip = tripPlan.selectedTrip!
  guard case .nonTransit(let nonTransitLeg) = trip.legs[0].modeLeg else {
    fatalError("unexpected legs for trip")
  }

  return Text("").sheet(isPresented: .constant(true)) {
    ManeuverListSheetContents(
      trip: trip, tripPlan: tripPlan, maneuvers: nonTransitLeg.maneuvers,
      currentDetent: .constant(initialDetentHeight), onGo: {}, onClose: {})
  }
}
