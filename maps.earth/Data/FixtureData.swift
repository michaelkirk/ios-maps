//
//  FixtureData.swift
//  maps.earth
//
//  Created by Michael Kirk on 2/5/24.
//

import Foundation

extension FixtureData.Places: Sequence {
  typealias Element = Place
  typealias Iterator = [Place].Iterator

  func makeIterator() -> Array<Place>.Iterator {
    self.all.makeIterator()
  }
}

extension FixtureData.Places {
  subscript(position: FixtureData.Places.PlaceIdx) -> Place {
    self.all[position.rawValue]
  }
}

struct FixtureData {
  struct Places {
    enum PlaceIdx: Int {
      case schoolhouse = 0
      case zeitgeist = 1
      case dubsea = 2
      case realfine = 3
    }

    let all: [Place] = {
      let response: AutocompleteResponse = load("autocomplete.json")
      let places = response.places
      return places
    }()
  }
  static var places: Places = Places()

  static var bikeTrips: [Trip] = {
    let response: TripPlanResponse = load("bike_plan.json")
    let trips = response.plan.itineraries.map { Trip(itinerary: $0) }
    return trips
  }()

  static var tripPlan: TripPlan = TripPlan(
    from: Self.places[.zeitgeist], to: Self.places[.realfine], trips: Self.bikeTrips)
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
