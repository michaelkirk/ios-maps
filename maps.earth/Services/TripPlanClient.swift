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
  var bounds: Bounds
  var legs: [ItineraryLeg]
}

struct TravelmuxPlan: Decodable {
  var itineraries: [Itinerary]
}

//  "bounds": {
//    "min": [
//      -122.349926,
//      47.575601
//    ],
//    "max": [
//      -122.336014,
//      47.652747
//    ]
//  },
struct Bounds: Decodable {
  var min: LngLat
  var max: LngLat

  private enum CodingKeys: String, CodingKey {
    case min
    case max
  }

  // Decode from an array format
  init(from decoder: Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let minCoords = try container.decode([Float64].self, forKey: .min)
    let maxCoords = try container.decode([Float64].self, forKey: .max)

    self.min = LngLat(lng: minCoords[0], lat: minCoords[1])
    self.max = LngLat(lng: maxCoords[0], lat: maxCoords[1])
  }
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

enum TravelMode: String {
  case walk = "WALK"
  case bike = "BICYCLE"
  case car = "CAR"
  case transit = "TRANSIT"
}

struct TripPlanClient {
  let config = AppConfig()
  func query(from: Place, to: Place, mode: TravelMode, units: DistanceUnit) async throws -> [Trip] {
    // URL: https://maps.earth/travelmux/v2/plan?fromPlace=47.575837%2C-122.339414&toPlace=47.622687%2C-122.312892&numItineraries=5&mode=TRANSIT&preferredDistanceUnits=miles

    let preferredDistanceUnits =
      switch units {
      case .kilometers: "kilometers"
      case .meters: "meters"
      case .miles: "miles"
      }

    var url = config.travelmuxEndpoint

    let params = [
      URLQueryItem(name: "fromPlace", value: "\(from.location.lat),\(from.location.lng)"),
      URLQueryItem(name: "toPlace", value: "\(to.location.lat),\(to.location.lng)"),
      URLQueryItem(name: "numItineraries", value: "5"),
      URLQueryItem(name: "mode", value: mode.rawValue),
      URLQueryItem(name: "preferredDistanceUnits", value: preferredDistanceUnits),
    ]
    url.append(queryItems: params)
    print("travelmux assembled url: \(url)")

    let response: TripPlanResponse = try await fetchData(from: url)
    let trips = response.plan.itineraries.map { itinerary in
      Trip(itinerary: itinerary, from: from, to: to)
    }
    return trips
  }

  private func fetchData<T: Decodable>(from url: URL) async throws -> T {
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw URLError(.badServerResponse)
    }

    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
    return decodedResponse
  }
}
