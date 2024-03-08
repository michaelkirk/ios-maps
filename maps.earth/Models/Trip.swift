//
//  Trip.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/4/24.
//

import CoreLocation
import Foundation

struct TripLeg {
  var geometry: [CLLocationCoordinate2D]
}

struct Trip: Identifiable {
  var raw: Itinerary
  let from: Place
  let to: Place

  //  var from: Place
  //  var to: Place

  // this is just to be Hashable. I'm not sure if we need it.
  var id: UUID

  var legs: [TripLeg]
  var duration: Float64 {
    self.raw.duration
  }
  var distance: Float64 {
    self.raw.distance
  }
  var distanceFormatUnit: LengthFormatter.Unit {
    switch self.raw.distanceUnits {
    case .miles:
      .mile
    case .meters:
      .meter
    case .kilometers:
      .kilometer
    }
  }

  var durationFormatted: String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .short
    formatter.zeroFormattingBehavior = .dropAll

    return formatter.string(from: self.duration) ?? "\(self.duration)s"
  }

  var distanceFormatted: String {
    let formatter = LengthFormatter()
    formatter.unitStyle = .long
    formatter.numberFormatter.roundingIncrement = 0.1
    return formatter.string(fromValue: distance, unit: self.distanceFormatUnit)
  }

  init(itinerary: Itinerary, from: Place, to: Place) {
    self.id = UUID()
    self.raw = itinerary
    self.legs = itinerary.legs.map { itineraryLeg in
      TripLeg(geometry: decodePolyline(itineraryLeg.geometry, precision: 6))
    }
    self.from = from
    self.to = to
  }
}

extension Trip: Hashable {
  static func == (lhs: Trip, rhs: Trip) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

func decodePolyline(_ str: String, precision: Int) -> [CLLocationCoordinate2D] {
  var lat = 0
  var lng = 0

  var coordinates: [CLLocationCoordinate2D] = []
  let factor = pow(10, Double(precision))

  // Coordinates have variable length when encoded, so just keep
  // track of whether we've hit the end of the string. In each
  // loop iteration, a single coordinate is decoded.
  var strIter = str.utf8.map { Int(Int8(bitPattern: $0)) - 63 }.makeIterator()

  repeat {

    let nextDelta = { () -> Int? in
      var shift = 0
      var result = 0

      repeat {
        guard let byte = strIter.next() else {
          return nil
        }
        result |= (byte & 0x1f) << shift
        shift += 5
        guard byte >= 0x20 else {
          break
        }
      } while true

      if result & 1 == 1 {
        return ~(result >> 1)
      } else {
        return result >> 1
      }
    }

    guard let latitudeChange = nextDelta() else {
      break
    }

    guard let longitudeChange = nextDelta() else {
      assertionFailure("latitude without matching longitude in polyline")
      break
    }

    lat += latitudeChange
    lng += longitudeChange

    let coord = CLLocationCoordinate2D(
      latitude: Double(lat) / factor, longitude: Double(lng) / factor)
    coordinates.append(coord)
  } while true
  return coordinates
}
