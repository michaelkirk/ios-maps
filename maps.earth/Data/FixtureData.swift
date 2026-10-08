//
//  FixtureData.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import CoreLocation
import Foundation

struct FixtureData {
  struct Places {
    let all: [Place] = {
      let response: AutocompleteResponse = load("autocomplete.json")
      var places = response.places

      let westSeattleWaterTaxi: PlaceResponse = load("west_seattle_water_taxi_place.json")
      assert(westSeattleWaterTaxi.places.count == 1)
      assert(places.count == 10)
      places.append(westSeattleWaterTaxi.places[0])

      return places
    }()
  }
  static var places: Places = Places()

  static var elevationProfile: ElevationProfile = load("trip_elevation.json")

  static var bikeTrips: [Trip] {
    var trips = loadTrips(filename: "bicycle_plan.json")
    trips = trips.map { trip in
      var mutableTrip = trip
      mutableTrip.setElevationProfile(Self.elevationProfile)
      return mutableTrip
    }
    return trips
  }

  static var walkTrips: [Trip] {
    var trips = loadTrips(filename: "walk_plan.json")
    trips = trips.map { trip in
      var mutableTrip = trip
      mutableTrip.setElevationProfile(Self.elevationProfile)
      return mutableTrip
    }
    return trips
  }

  /// Capitol Hill by bike, with steep sections from travelmux.
  static var bikeGradeTrips: [Trip] {
    loadTrips(filename: "bicycle_grades_plan.json")
  }

  static var driveTrips: [Trip] {
    loadTrips(filename: "car_plan.json")
  }

  static var transitTrips: [Trip] {
    loadTrips(filename: "transit_plan.json")
  }

  static var bikeTripError: TripPlanError {
    loadTripError(filename: "bicycle_plan_error.json")
  }

  @MainActor
  static var tripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], trips: .success(Self.walkTrips))

  @MainActor
  static var walkTripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], trips: .success(Self.walkTrips))

  @MainActor
  static var bikeTripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], trips: .success(Self.bikeTrips))

  @MainActor
  static var bikeGradeTripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], mode: .bike,
    trips: .success(Self.bikeGradeTrips))

  @MainActor
  static var driveTripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], trips: .success(Self.driveTrips))

  @MainActor
  static var transitTripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], trips: .success(Self.transitTrips))

  static func loadTrips(filename: String) -> [Trip] {
    let response: TripPlanResponse = loadTravelmux(filename)
    let trips = response.itineraries.map { itinerary in
      Trip(itinerary: itinerary, from: self.places[.realfine], to: self.places[.zeitgeist])
    }
    return trips
  }

  static func loadTripError(filename: String) -> TripPlanError {
    let errorResponse: TripPlanErrorResponse = loadTravelmux(filename)
    return errorResponse.error
  }
}

func loadData(_ filename: String) -> Data {
  guard let file = Bundle.main.url(forResource: filename, withExtension: nil) else {
    fatalError("Couldn't find \(filename) in main bundle.")
  }

  do {
    return try Data(contentsOf: file)
  } catch {
    fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
  }
}

func loadTravelmux<T: Decodable>(_ filename: String) -> T {
  do {
    return try JSONDecoder.travelmux.decode(T.self, from: loadData(filename))
  } catch {
    fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
  }
}

func load<T: Decodable>(_ filename: String) -> T {
  let data = loadData(filename)

  do {
    let decoder = JSONDecoder()
    // pelias conventions are snake_case
    // TODO: account for this at a higher scope, otherwise we'll have to sprinkle it around here and in our client
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(T.self, from: data)
  } catch {
    fatalError("Couldn't parse \(filename) as \(T.self):\n\(error)")
  }
}

extension FixtureData.Places {
  enum PlaceIdx: Int {
    case schoolhouse = 0
    case zeitgeist = 1
    case dubsea = 2
    case realfine = 3
    case santaLucia = 4
    case westSeattleWaterTaxi = 10
  }

  subscript(position: PlaceIdx) -> Place {
    self.all[position.rawValue]
  }
}

extension TransitVehicle {
  static func fixture(
    route: TransitRoute = TransitRoute(shortName: "5", longName: nil, color: "FDB71A"),
    mode: TransitVehicleMode = .bus,
    label: String? = "8293",
    lastUpdated: Date,
    boardingStop: BoardingStop?
  ) -> TransitVehicle {
    TransitVehicle(
      id: "vehicle-1",
      patternCode: "pattern-1",
      route: route,
      vehicleMode: mode,
      headsign: "Shoreline Greenwood",
      vehicleId: "f-c23-metrokingcounty:8293",
      label: label,
      position: LonLatPair(LngLat(lng: -122.35, lat: 47.65)),
      lastUpdated: lastUpdated,
      track: nil,
      boardingStop: boardingStop)
  }
}

extension VehiclePositionsResponse {
  /// A made-up train one stop short of the trip's first boarding stop, for App Store screenshots.
  static func screenshotTrain(approaching trip: Trip, now: Date = .now) -> Self? {
    guard let leg = trip.legs.first(where: { $0.transitLeg != nil }),
      let transitLeg = leg.transitLeg, let patternCode = transitLeg.patternCode,
      let route = transitLeg.route, let pattern = leg.patternGeometry,
      let contextStops = leg.contextStops
    else {
      return nil
    }

    let boardingIdx = pattern.nearestIndex(to: leg.fromPlace.location.asCoordinate)
    guard
      let previousStop =
        contextStops
        .map({ (stop: $0, idx: pattern.nearestIndex(to: $0)) })
        .filter({ $0.idx < boardingIdx })
        .max(by: { $0.idx < $1.idx })?.stop
    else {
      return nil
    }

    let arrival = now.addingTimeInterval(5 * 60)
    let train = TransitVehicle(
      id: "screenshot-train-\(patternCode)",
      patternCode: patternCode,
      route: route,
      vehicleMode: transitLeg.vehicleMode,
      headsign: transitLeg.headsign,
      vehicleId: nil,
      label: nil,
      position: LonLatPair(LngLat(lng: previousStop.longitude, lat: previousStop.latitude)),
      lastUpdated: now,
      track: nil,
      boardingStop: .approaching(arrival: arrival, stopArrivals: [arrival]))
    return Self(vehicles: [train], serverTime: now, unknownPatterns: nil)
  }
}

extension [CLLocationCoordinate2D] {
  /// The index of the point closest to `coordinate`.
  fileprivate func nearestIndex(to coordinate: CLLocationCoordinate2D) -> Int {
    let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    return indices.min {
      CLLocation(latitude: self[$0].latitude, longitude: self[$0].longitude).distance(from: target)
        < CLLocation(latitude: self[$1].latitude, longitude: self[$1].longitude).distance(
          from: target)
    } ?? 0
  }
}
