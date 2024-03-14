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

struct ManeuverList: View {
  var maneuvers: [Maneuver]
  init(maneuvers: [Maneuver]) {
    print("maneuvers: \(maneuvers)")
    self.maneuvers = maneuvers
  }

  var body: some View {
    let maneuversElements = maneuvers.enumerated().map { ManeuverElement(maneuver: $1, id: $0) }
    Text("Steps")
    List(maneuversElements) { el in
      let maneuver = el.maneuver

      HStack {
        Text("\(maneuver.type)").frame(width: 50)
        //        image(maneuverType: maneuver.type)
        VStack(alignment: .leading) {
          Text(maneuver.instruction)
          if let verbalPostTransitionInstruction = maneuver.verbalPostTransitionInstruction {
            Text(verbalPostTransitionInstruction).foregroundColor(.secondary)
          }
        }
      }
    }
  }
}

#Preview("Walking Maneuvers") {
  let trip = FixtureData.walkTrips[0]
  let maneuvers = trip.maneuvers!
  return ManeuverList(maneuvers: maneuvers)
}
