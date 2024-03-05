//
//  Trip.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/4/24.
//

import CoreLocation
import Foundation

struct Trip: Hashable {
  var from: Place
  var to: Place
  var encodedGeometry: String
  var decodedGeometry: [CLLocationCoordinate2D] {
    decodePolyline(encodedGeometry, precision: 6)
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
