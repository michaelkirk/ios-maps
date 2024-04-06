//
//  Valhalla.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/14/24.
//

import Foundation

/// From https://valhalla.github.io/valhalla/api/turn-by-turn/api-reference/#trip-legs-and-maneuvers
enum ValhallaManeuverType: Int, Decodable {
  case none = 0
  case start = 1
  case startRight = 2
  case startLeft = 3
  case destination = 4
  case destinationRight = 5
  case destinationLeft = 6
  case becomes = 7
  case `continue` = 8
  case slightRight = 9
  case right = 10
  case sharpRight = 11
  case uturnRight = 12
  case uturnLeft = 13
  case sharpLeft = 14
  case left = 15
  case slightLeft = 16
  case rampStraight = 17
  case rampRight = 18
  case rampLeft = 19
  case exitRight = 20
  case exitLeft = 21
  case stayStraight = 22
  case stayRight = 23
  case stayLeft = 24
  case merge = 25
  case roundaboutEnter = 26
  case roundaboutExit = 27
  case ferryEnter = 28
  case ferryExit = 29
  case transit = 30
  case transitTransfer = 31
  case transitRemainOn = 32
  case transitConnectionStart = 33
  case transitConnectionTransfer = 34
  case transitConnectionDestination = 35
  case postTransitConnectionDestination = 36
  case mergeRight = 37
  case mergeLeft = 38
  case elevatorEnter = 39
  case stepsEnter = 40
  case escalatorEnter = 41
  case buildingEnter = 42
  case buildingExit = 43

  static var allCases: [ManeuverType] {
    (0...43).map { ManeuverType(rawValue: $0)! }
  }
}
