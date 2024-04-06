//
//  TripPlanClient.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/5/24.
//

import Foundation

struct NamedPlace: Decodable {
  var place: LngLat
  var name: String
}

typealias TransitLeg = OTPTransitLeg

enum ModeLeg: Decodable {
  case transit(TransitLeg)
  case nonTransit([Maneuver])
}

struct ItineraryLeg {
  var geometry: String
  var modeLeg: ModeLeg
}

extension ItineraryLeg: Decodable {
  private enum CodingKeys: String, CodingKey {
    case geometry
    case maneuvers
    case transitLeg
  }

  // Decode from an array format
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let geometry = try container.decode(String.self, forKey: .geometry)

    let modeLeg: ModeLeg
    if let maneuvers = try container.decodeIfPresent([Maneuver].self, forKey: .maneuvers) {
      modeLeg = .nonTransit(maneuvers)
    } else {
      let transitLeg = try container.decode(TransitLeg.self, forKey: .transitLeg)
      modeLeg = .transit(transitLeg)
    }

    self.init(geometry: geometry, modeLeg: modeLeg)
  }
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
  var startTime: UInt64
  var endTime: UInt64
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

// At some point we might want to abstract this, but Valhalla's ManeuverType seems strictly more precise than OTP's
typealias ManeuverType = ValhallaManeuverType

struct Maneuver: Decodable {
  //  var begin_shape_index: Int
  //  var end_shape_index: Int
  //  var cost: Float64

  // TODO?
  // // For Valhalla this would always be the same as the trip Mode
  // // For OTP transit routing this will be a combination of the transit modes and
  // // the connecting mode (either walking or biking)
  // var mode: TravelMode

  // Always present for valhalla directions, but currently nil for OTP
  var instruction: String?

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

struct TripPlanErrorResponse: Decodable, Error {
  var error: TripPlanError
}

struct TripPlanError: Decodable, Error {
  var message: String
  var errorCode: TripPlanErrorCode
  var statusCode: UInt16
}

enum TripPlanErrorCode: Equatable {
  case tooFarForDirections
  case other(UInt32)
  init(rawValue: UInt32) {
    switch rawValue {
    case 2154:
      self = .tooFarForDirections
    default:
      self = .other(rawValue)
    }
  }
}

extension TripPlanErrorCode: Decodable {
  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let decodedValue = try container.decode(UInt32.self)
    self.init(rawValue: decodedValue)
  }
}

extension TripPlanError: LocalizedError {
  var errorDescription: String? {
    switch errorCode {
    case .tooFarForDirections:
      fallthrough
    default:
      return "Error getting directions — \(message)"
    }
  }
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

enum TravelMode: String, Decodable {
  case walk = "WALK"
  case bike = "BICYCLE"
  case car = "CAR"
  case transit = "TRANSIT"

  var emoji: String {
    switch self {
    case .walk:
      OTPTravelMode.walk.emoji
    case .bike:
      OTPTravelMode.bicycle.emoji
    case .car:
      OTPTravelMode.car.emoji
    case .transit:
      OTPTravelMode.transit.emoji
    }
  }
}

protocol TripPlanClient {
  typealias RealClient = TripPlanNetworkClient
  typealias MockClient = TripPlanMockClient

  func query(from: Place, to: Place, mode: TravelMode, units: DistanceUnit) async throws -> Result<
    [Trip], TripPlanError
  >
}

struct TripPlanMockClient: TripPlanClient {
  func query(from: Place, to: Place, mode: TravelMode, units: DistanceUnit) async throws -> Result<
    [Trip], TripPlanError
  > {
    .success(FixtureData.bikeTrips)
  }
}

struct TripPlanNetworkClient: TripPlanClient {
  let config = AppConfig()
  func query(from: Place, to: Place, mode: TravelMode, units: DistanceUnit) async throws -> Result<
    [Trip], TripPlanError
  > {
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
    // print("travelmux assembled url: \(url)")

    let result: Result<[Trip], TripPlanErrorResponse> = try await fetchData(from: url).map {
      (response: TripPlanResponse) in
      response.plan.itineraries.map { itinerary in
        Trip(itinerary: itinerary, from: from, to: to)
      }
    }
    return result.mapError { $0.error }
  }

  private func fetchData<T: Decodable, E: Decodable>(from url: URL) async throws -> Result<T, E> {
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      let decodedResponse = try JSONDecoder().decode(E.self, from: data)
      return .failure(decodedResponse)
    }

    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
    return .success(decodedResponse)
  }
}
