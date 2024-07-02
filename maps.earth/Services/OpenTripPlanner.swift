//
//  OpenTripPlanner.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/5/24.
//

import Foundation

// Currently we don't use any field from this part of the response
struct OTPPlan: Decodable {

}

enum OTPTravelMode: String, Decodable {
  case walk = "WALK"
  case bicycle = "BICYCLE"
  case car = "CAR"
  case tram = "TRAM"
  case subway = "SUBWAY"
  case rail = "RAIL"
  case bus = "BUS"
  case ferry = "FERRY"
  case cableCar = "CABLE_CAR"
  case gondola = "GONDOLA"
  case funicular = "FUNICULAR"
  case transit = "TRANSIT"

  var emoji: String {
    switch self {
    case .walk:
      return "🚶‍♀️"
    case .bus, .transit:
      return "🚍"
    case .rail:
      return "🚆"
    case .subway:
      return "🚇"
    case .bicycle:
      return "🚲"
    case .cableCar, .tram:
      return "🚊"
    case .funicular:
      return "🚡"
    case .gondola:
      return "🚠"
    case .car:
      return "🚙"
    case .ferry:
      return "⛴️"
    default:
      print("error: no emoji for mode: \(self)")
      return ""
    }
  }
}

struct OTPTransitLeg: Decodable {
  var startTime: Int64
  //  var endTime: Int64
  var mode: OTPTravelMode
  //  var transitLeg: Bool

  /// Whether there is real-time data about this Leg
  var realTime: Bool

  // Not always set - e.g. 1-Line in seattle has it set, but not bus lines
  var route: String?
  var routeShortName: String?
  //  var routeLongName: String?
  var routeColor: String?

  var from: TripPlace  //{ name: string; lat: number; lon: number };
  //  var to: TripPlace  // { name: string; lat: number; lon: number };
  //  var alerts: OTPAlert[];

  var routeSummaryName: String {
    if let routeShortName = routeShortName {
      return routeShortName
    } else if let route = route {
      return route
    } else {
      print("error: no route summary name for leg with mode \(mode)")
      return ""
    }
  }

  var startDate: Date {
    Date(millisSince1970: UInt64(startTime))
  }

  var departureName: String? { from.name }
}
