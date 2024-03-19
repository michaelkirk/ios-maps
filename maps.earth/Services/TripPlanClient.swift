//
//  TripPlanClient.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/5/24.
//

import Foundation

struct ItineraryLeg: Decodable {
  var geometry: String
  var maneuvers: [Maneuver]?
}

enum DistanceUnit: String, Decodable {
  case miles
  case meters
  case kilometers

  func toLengthFormatterUnit() -> LengthFormatter.Unit {
    switch self {
    case .miles:
      .mile
    case .meters:
      .meter
    case .kilometers:
      .kilometer
    }
  }

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
}

extension Bounds {
  private enum CodingKeys: String, CodingKey {
    case min
    case max
  }

  // Decode from an array format
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let minCoords = try container.decode([Float64].self, forKey: .min)
    let maxCoords = try container.decode([Float64].self, forKey: .max)

    self.min = LngLat(lng: minCoords[0], lat: minCoords[1])
    self.max = LngLat(lng: maxCoords[0], lat: maxCoords[1])
  }

  init?(lngLats: [LngLat]) {
    var iter = lngLats.makeIterator()
    guard let first = iter.next() else {
      return nil
    }
    self.min = first
    self.max = first

    for coord in iter {
      self.extend(lngLat: coord)
    }
  }

  mutating func extend(lngLat: LngLat) {
    if lngLat.lng < self.min.lng {
      self.min.lng = lngLat.lng
    }
    if lngLat.lng > self.max.lng {
      self.max.lng = lngLat.lng
    }
    if lngLat.lat < self.min.lat {
      self.min.lat = lngLat.lat
    }
    if lngLat.lat > self.max.lat {
      self.max.lat = lngLat.lat
    }
  }
}

struct OTPPlan: Decodable {

}

/// From https://valhalla.github.io/valhalla/api/turn-by-turn/api-reference/#trip-legs-and-maneuvers
enum ManeuverType: Int, Decodable {
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

  static var allCases: [ManeuverType] {
    (0...38).map { ManeuverType(rawValue: $0)! }
  }
}

struct Maneuver: Decodable {
  //  var begin_shape_index: Int
  //  var end_shape_index: Int
  var cost: Float64

  var instruction: String

  //  var length: Float64
  //  var time: Float64
  //  var travel_mode: String
  //  var travel_type: String

  // 2
  var type: ManeuverType

  // "Walk south on the walkway."
  // var verbalPreTransitionInstruction: String?

  // "Continue for 200 feet."
  /// Empty for final maneuver
  /// verbal_post_transition_instruction
  var verbalPostTransitionInstruction: String?

  // "Walk south.
  //  var verbal_succinct_transition_instruction: String
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
