//
//  TripPlanClient.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/5/24.
//

import FerrostarCore
import FerrostarCoreFFI
import Foundation
import MapboxDirections

typealias TransitLeg = OTPTransitLeg

extension TransitLeg {
  var emojiRouteLabel: String {
    "\(mode.emoji) \(routeSummaryName)"
  }
}

struct NonTransitLeg {
  let maneuvers: [Maneuver]
  let substantialStreetNames: [String]
}

extension NonTransitLeg: Decodable {
  private enum CodingKeys: String, CodingKey {
    case maneuvers
    case substantialStreetNames
  }
}

enum ModeLeg {
  case transit(TransitLeg)
  case nonTransit(NonTransitLeg)
}

struct ItineraryLeg {
  var geometry: String
  var fromPlace: TripPlace
  var toPlace: TripPlace
  var startTime: Date
  var endTime: Date
  var mode: TravelMode
  var modeLeg: ModeLeg
}

extension TripPlace: Decodable {
  private enum CodingKeys: String, CodingKey {
    case lon
    case lat
    case name
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let name = try container.decodeIfPresent(String.self, forKey: .name)
    let lon = try container.decode(Float64.self, forKey: .lon)
    let lat = try container.decode(Float64.self, forKey: .lat)
    // note spellings is different... this is a difference between the valhalla and OTP APIs vs. Maplibre
    let lngLat = LngLat(lng: lon, lat: lat)
    self.init(location: lngLat, name: name)
  }
}

extension ItineraryLeg: Decodable {
  private enum CodingKeys: String, CodingKey {
    case geometry
    case mode
    case nonTransitLeg
    case transitLeg
    case fromPlace
    case toPlace
    case startTime
    case endTime
  }

  // Decode from an array format
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let geometry = try container.decode(String.self, forKey: .geometry)
    let mode = try container.decode(TravelMode.self, forKey: .mode)

    let fromPlace = try container.decode(TripPlace.self, forKey: .fromPlace)
    let toPlace = try container.decode(TripPlace.self, forKey: .toPlace)

    let startTimeMillis = try container.decode(UInt64.self, forKey: .startTime)
    let startTime = Date(millisSince1970: startTimeMillis)
    let endTimeMillis = try container.decode(UInt64.self, forKey: .endTime)
    let endTime = Date(millisSince1970: endTimeMillis)

    let modeLeg: ModeLeg
    if let nonTransitLeg = try container.decodeIfPresent(NonTransitLeg.self, forKey: .nonTransitLeg)
    {
      modeLeg = .nonTransit(nonTransitLeg)
    } else {
      let transitLeg = try container.decode(TransitLeg.self, forKey: .transitLeg)
      modeLeg = .transit(transitLeg)
    }

    self.init(
      geometry: geometry, fromPlace: fromPlace, toPlace: toPlace, startTime: startTime,
      endTime: endTime, mode: mode, modeLeg: modeLeg)
  }
}

extension Date {
  init(millisSince1970 millis: UInt64) {
    self.init(timeIntervalSince1970: Double(millis) / 1000)
  }
}

enum DistanceUnit: String, Decodable, Encodable {
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
  var mode: TravelMode
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
struct Bounds {
  var min: LngLat
  var max: LngLat
}

extension Bounds: Decodable {
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
}

extension Bounds {
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

  init(bbox: BBox) {
    self.init(min: bbox.min, max: bbox.max)
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

enum TravelMode: String, Codable, Equatable {
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

  func query(
    from: Place, to: Place, modes: [TravelMode], measurementSystem: MeasurementSystem,
    tripDate: TripDateMode
  )
    async throws -> Result<
      [Trip], TripPlanError
    >

  func elevation(polyline: String) async throws -> Result<ElevationProfile, TripPlanError>
}

struct TripPlanMockClient: TripPlanClient {
  func query(
    from: Place, to: Place, modes: [TravelMode], measurementSystem: MeasurementSystem,
    tripDate: TripDateMode
  )
    async throws -> Result<
      [Trip], TripPlanError
    >
  {
    .success(FixtureData.bikeTrips)
  }

  func elevation(polyline: String) async throws -> Result<ElevationProfile, TripPlanError> {
    .success(FixtureData.elevationProfile)
  }
}

struct TripPlanNetworkClient: TripPlanClient {
  let config = AppConfig()

  struct QueryParams {
    static var timeFormatter: DateFormatter = {
      let timeFormatter = DateFormatter()
      timeFormatter.dateFormat = "HH:mm"
      return timeFormatter
    }()

    static var dateFormatter: DateFormatter = {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "YYYY-MM-dd"
      return dateFormatter
    }()

    var from: LngLat
    var to: LngLat
    var modes: [TravelMode]
    var measurementSystem: MeasurementSystem
    var tripDate: TripDateMode

    var asQueryItems: [URLQueryItem] {
      assert(!modes.isEmpty)

      let preferredDistanceUnits =
        switch measurementSystem {
        case .metric: "kilometers"
        case .imperial: "miles"
        }

      var queryItems = [
        URLQueryItem(name: "fromPlace", value: "\(from.lat),\(from.lng)"),
        URLQueryItem(name: "toPlace", value: "\(to.lat),\(to.lng)"),
        URLQueryItem(name: "numItineraries", value: "5"),
        URLQueryItem(name: "mode", value: modes.map { $0.rawValue }.joined(separator: ",")),
        URLQueryItem(name: "preferredDistanceUnits", value: preferredDistanceUnits),
      ]

      if modes[0] == .transit {
        switch tripDate {
        case .departNow:
          break
        case .departAt(let date):
          // time=16%3A50&date=2024-04-24
          let time = Self.timeFormatter.string(from: date)
          queryItems.append(URLQueryItem(name: "time", value: time))

          let date = Self.dateFormatter.string(from: date)
          queryItems.append(URLQueryItem(name: "date", value: date))
        case .arriveBy(let date):
          // time=16%3A50&date=2024-04-24&arriveBy=true
          let time = Self.timeFormatter.string(from: date)
          queryItems.append(URLQueryItem(name: "time", value: time))

          let date = Self.dateFormatter.string(from: date)
          queryItems.append(URLQueryItem(name: "date", value: date))

          queryItems.append(URLQueryItem(name: "arriveBy", value: "true"))
        }
      }

      return queryItems
    }
  }

  func query(
    from: Place, to: Place, modes: [TravelMode], measurementSystem: MeasurementSystem,
    tripDate: TripDateMode
  )
    async throws -> Result<
      [Trip], TripPlanError
    >
  {
    let params = Self.QueryParams(
      from: from.location, to: to.location, modes: modes, measurementSystem: measurementSystem,
      tripDate: tripDate)

    // URL: https://maps.earth/travelmux/v2/plan?fromPlace=47.575837%2C-122.339414&toPlace=47.622687%2C-122.312892&numItineraries=5&mode=TRANSIT&preferredDistanceUnits=miles
    let url = AppConfig().travelmuxEndpoint.appending(path: "plan").appending(
      queryItems: params.asQueryItems)

    print("travelmux assembled url: \(url)")

    let result: Result<[Trip], TripPlanErrorResponse> = try await fetchData(from: url).map {
      (response: TripPlanResponse) in
      response.plan.itineraries.map { itinerary in
        Trip(itinerary: itinerary, from: from, to: to)
      }
    }
    return result.mapError { $0.error }
  }

  func elevation(polyline: String) async throws -> Result<ElevationProfile, TripPlanError> {
    let queryItems = [URLQueryItem(name: "path", value: polyline)]
    let url = AppConfig().travelmuxEndpoint.appending(path: "elevation").appending(
      queryItems: queryItems)
    return try await fetchData(from: url).mapError { (err: TripPlanErrorResponse) in err.error }
  }

  internal func fetchData<T: Decodable, E: Decodable>(from url: URL) async throws -> Result<T, E> {
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      let decodedResponse = try JSONDecoder().decode(E.self, from: data)
      return .failure(decodedResponse)
    }

    let decodedResponse = try JSONDecoder().decode(T.self, from: data)
    return .success(decodedResponse)
  }
}

struct TripPlanClientFerrostarAdapter {
  let tripPlanNetworkClient: TripPlanNetworkClient
  let travelMode: TravelMode
  let measurementSystem: MeasurementSystem
}

extension TripPlanClientFerrostarAdapter: CustomRouteProvider {
  func getRoutes(
    userLocation: FerrostarCoreFFI.UserLocation, waypoints: [FerrostarCoreFFI.Waypoint]
  ) async throws -> [FerrostarCoreFFI.Route] {
    guard let toWaypoint = waypoints.last else {
      fatalError("TODO: handle missing waypoint gracefully")
    }
    assert(waypoints.count == 1, "only 1 waypoint is supported")
    // TODO: handle destinationName
    let to = Place(location: toWaypoint.coordinate.lngLat.asCLLocation)
    let from = Place(currentLocation: userLocation.clLocation)

    let routes = try await DirectionsService().routes(
      from: from, to: to, mode: self.travelMode, transitWithBike: false)
    return routes.map { FerrostarCoreFFI.Route(mapboxRoute: $0) }
  }
}

extension GeographicCoordinate {
  var lngLat: LngLat {
    LngLat(lng: self.lng, lat: self.lat)
  }
}
