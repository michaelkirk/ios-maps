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
  default:
    nil
  }
}

struct ManeuverList: View {
  var trip: Trip
  var maneuvers: [Maneuver]

  var body: some View {
    let maneuversElements = maneuvers.enumerated().map {
      ManeuverElement(maneuver: $1, id: $0)
    }

    VStack(alignment: .leading) {
      Text("\(trip.durationFormatted) (\(trip.distanceFormatted))").scenePadding(.leading).bold()
      List(maneuversElements) { el in
        let maneuver = el.maneuver
        HStack(spacing: 16) {
          image(maneuverType: maneuver.type).imageScale(.large)
          VStack(alignment: .leading) {
            if let instruction = maneuver.instruction {
              Text(instruction)
            }
            if let verbalPostTransitionInstruction = maneuver.verbalPostTransitionInstruction {
              Text(verbalPostTransitionInstruction).foregroundColor(.secondary)
            }
          }
          Spacer()
        }
      }.hwListStyle()
    }
  }
}

struct ManeuverListSheetContents: View {
  var trip: Trip
  var maneuvers: [Maneuver]
  var onClose: () -> Void

  var body: some View {
    SheetContents(
      title: "Steps", onClose: onClose, presentationDetents: [.large],
      currentDetent: .constant(.large)
    ) {
      ManeuverList(trip: trip, maneuvers: maneuvers)
    }
  }
}

#Preview("Walking Maneuvers") {
  let trip = FixtureData.walkTrips[0]
  guard case .nonTransit(let nonTransitLeg) = trip.legs[0].modeLeg else {
    fatalError("unexpected legs for trip")
  }

  return Text("").sheet(isPresented: .constant(true)) {
    ManeuverListSheetContents(trip: trip, maneuvers: nonTransitLeg.maneuvers, onClose: {})
  }
}

#Preview("All Maneuvers") {
  var trip = FixtureData.walkTrips[0]
  let maneuvers = ManeuverType.allCases.map { maneuver in
    Maneuver(
      instruction: "maneuver: \(maneuver)", type: maneuver,
      verbalPostTransitionInstruction: "Go 123 miles.")
  }

  return Text("").sheet(isPresented: .constant(true)) {
    ManeuverListSheetContents(trip: trip, maneuvers: maneuvers, onClose: {})
  }
}
