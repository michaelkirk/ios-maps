//
//  FixtureData.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

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

  static var bikeTrips: [Trip] {
    loadTrips(filename: "bicycle_plan.json")
  }

  static var walkTrips: [Trip] {
    loadTrips(filename: "walk_plan.json")
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

  static var tripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], mode: .walk,
    trips: .success(Self.walkTrips))

  static var walkTripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], mode: .walk,
    trips: .success(Self.walkTrips))

  static var bikeTripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], mode: .bike,
    trips: .success(Self.bikeTrips))

  static var driveTripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], mode: .car,
    trips: .success(Self.driveTrips))

  static var transitTripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], mode: .transit,
    trips: .success(Self.transitTrips))

  static func loadTrips(filename: String) -> [Trip] {
    let response: TripPlanResponse = load(filename)
    let trips = response.plan.itineraries.map { itinerary in
      Trip(itinerary: itinerary, from: self.places[.realfine], to: self.places[.zeitgeist])
    }
    return trips
  }

  static func loadTripError(filename: String) -> TripPlanError {
    let errorResponse: TripPlanErrorResponse = load(filename)
    return errorResponse.error
  }
}

func load<T: Decodable>(_ filename: String) -> T {
  let data: Data

  guard let file = Bundle.main.url(forResource: filename, withExtension: nil) else {
    fatalError("Couldn't find \(filename) in main bundle.")
  }

  do {
    data = try Data(contentsOf: file)
  } catch {
    fatalError("Couldn't load \(filename) from main bundle:\n\(error)")
  }

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
