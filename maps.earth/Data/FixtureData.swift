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
      let places = response.places
      return places
    }()
  }
  static var places: Places = Places()

  static var bikeTrips: [Trip] {
    let response: TripPlanResponse = load("bike_plan.json")
    let trips = response.plan.itineraries.map { itinerary in
      Trip(itinerary: itinerary, from: self.places[.realfine], to: self.places[.zeitgeist])
    }
    return trips
  }

  // FIXME: FROM/TO do not match the trips - I need my fixtures to be consistent
  static var tripPlan: TripPlan = TripPlan(
    from: Self.places[.realfine], to: Self.places[.zeitgeist], mode: .bike, trips: Self.bikeTrips)
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
  }

  subscript(position: PlaceIdx) -> Place {
    self.all[position.rawValue]
  }
}
