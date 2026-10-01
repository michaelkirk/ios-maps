//
//  TransitVehicleMode.swift
//  maps.earth
//
//  Created by Michael Kirk on 4/5/24.
//

import Foundation

/// The kind of vehicle a transit ride is on, as OTP names it.
///
/// Travelmux passes OTP's value through verbatim, and OTP has more of these than we've named, so
/// anything we don't recognize is treated as generic transit.
enum TransitVehicleMode: Equatable {
  case tram
  case subway
  case rail
  case bus
  case coach
  case ferry
  case cableCar
  case gondola
  case funicular
  case trolleybus
  case monorail
  case transit
  case other(String)
}

extension TransitVehicleMode: Decodable {
  init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    self =
      switch value {
      case "TRAM": .tram
      case "SUBWAY": .subway
      case "RAIL": .rail
      case "BUS": .bus
      case "COACH": .coach
      case "FERRY": .ferry
      case "CABLE_CAR": .cableCar
      case "GONDOLA": .gondola
      case "FUNICULAR": .funicular
      case "TROLLEYBUS": .trolleybus
      case "MONORAIL": .monorail
      case "TRANSIT": .transit
      default: .other(value)
      }
  }
}

extension TransitVehicleMode {
  var emoji: String {
    switch self {
    case .bus, .coach, .trolleybus, .transit, .other: "🚍"
    case .rail, .monorail: "🚆"
    case .subway: "🚇"
    case .cableCar, .tram: "🚊"
    case .funicular: "🚡"
    case .gondola: "🚠"
    case .ferry: "⛴️"
    }
  }
}
