//
//  TripPlanClient.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/5/24.
//

import Foundation

struct ItineraryLeg: Decodable {
  var geometry: String
}

enum DistanceUnit: String, Decodable {
  case miles
  case meters
  case kilometers

  func toUnit() -> UnitLength {
    switch self {

    case .miles:
        .miles
    case .meters:
        .meters
    case .kilometers:
        .kilometers
    }
  }
}

struct Itinerary: Decodable {
  var mode: String
  var duration: Float64
  var distance: Float64
  var distanceUnits: DistanceUnit
  var legs: [ItineraryLeg]
}

struct TravelmuxPlan: Decodable {
  var itineraries: [Itinerary]
}

struct OTPPlan: Decodable {

}

struct ValhallaPlan: Decodable {

}

struct TripPlanResponse: Decodable {
  var plan: TravelmuxPlan
  var otp: OTPPlan?
  var valhalla: ValhallaPlan?

  private enum CodingKeys: String, CodingKey {
    case plan
    case _otp
    case _valhalla
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.plan = try container.decode(TravelmuxPlan.self, forKey: .plan)

    self.otp = try container.decodeIfPresent(OTPPlan.self, forKey: ._otp)
    self.valhalla = try container.decodeIfPresent(ValhallaPlan.self, forKey: ._valhalla)
  }
}
