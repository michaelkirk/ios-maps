//
//  Trip.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/4/24.
//

import CoreLocation
import Foundation
import SwiftUI

struct TripPlace: Hashable, Equatable {
  var location: LngLat
  var name: String?
}

struct TripLeg {
  var geometry: [CLLocationCoordinate2D]
  var fromPlace: TripPlace
  var toPlace: TripPlace
  var startTime: Date
  var endTime: Date
  var mode: TravelMode
  var modeLeg: ModeLeg

  var duration: Duration {
    Duration.seconds(endTime.timeIntervalSince(startTime))
  }

  var activeLineColor: Color {
    if case .transit(let transitLeg) = self.modeLeg,
      let routeColor = transitLeg.routeColor,
      let color = Color(hexString: routeColor)
    {
      color
    } else {
      Color.hw_activeRoute
    }
  }
}

struct FormattedElevationProfile {
  let raw: ElevationProfile
  let formatLocale: Locale

  var formattedTotalClimb: String {
    format(meters: raw.totalClimbMeters)
  }

  var formattedTotalFall: String {
    format(meters: raw.totalFallMeters)
  }

  func format(meters: Double) -> String {
    let formatter = MeasurementFormatter()
    formatter.locale = self.formatLocale
    formatter.unitStyle = .medium
    formatter.unitOptions = .providedUnit
    formatter.numberFormatter.roundingIncrement = 1.0

    let outputUnit =
      self.formatLocale.measurementSystem == .metric ? UnitLength.meters : UnitLength.feet
    let measurement = Measurement(value: meters, unit: .meters).converted(to: outputUnit)
    return formatter.string(from: measurement)
  }
}

struct ElevationProfile: Codable {
  let totalClimbMeters: Float64
  let totalFallMeters: Float64
  let elevation: [Float64]
}

struct Trip: Identifiable {
  let raw: Itinerary
  private(set) var elevationProfile: FormattedElevationProfile?
  mutating func setElevationProfile(_ profile: ElevationProfile) {
    self.elevationProfile = FormattedElevationProfile(raw: profile, formatLocale: self.formatLocale)
  }

  let id: UUID
  let from: Place
  let to: Place

  /// leave nil to use the current Locale
  var _formatLocale: Locale?
  var formatLocale: Locale {
    _formatLocale ?? Locale.current
  }

  var legs: [TripLeg]
  var duration: Float64 {
    self.raw.duration
  }

  var startTime: Date {
    Date(timeIntervalSince1970: Double(self.raw.startTime) / 1000)
  }

  var endTime: Date {
    Date(timeIntervalSince1970: Double(self.raw.endTime) / 1000)
  }

  var timeSpanFormatted: String {
    let timeStyle = Date.FormatStyle()
      .hour()
      .minute()
    return "\(startTime.formatted(timeStyle)) - \(endTime.formatted(timeStyle))"
  }

  var distance: Float64 {
    self.raw.distance
  }

  // the native unit of the stored `distance`
  var distanceUnit: DistanceUnit {
    self.raw.distanceUnits
  }

  var durationFormatted: String {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.hour, .minute]
    formatter.unitsStyle = .short
    formatter.zeroFormattingBehavior = .dropAll

    return formatter.string(from: self.duration) ?? "\(self.duration)s"
  }

  var distanceFormatted: String {
    let formatter = MeasurementFormatter()
    formatter.locale = self.formatLocale
    formatter.unitStyle = .long
    formatter.unitOptions = .providedUnit
    formatter.numberFormatter.roundingIncrement = 0.1

    let outputUnit =
      self.formatLocale.measurementSystem == .metric ? UnitLength.kilometers : UnitLength.miles
    let measurement = Measurement(value: distance, unit: distanceUnit.toUnit()).converted(
      to: outputUnit)

    return formatter.string(from: measurement)
  }

  var substantialStreetNames: String? {
    let names = legs.flatMap({ leg -> [String] in
      if case .nonTransit(let nonTransitLeg) = leg.modeLeg {
        return nonTransitLeg.substantialStreetNames
      } else {
        return []
      }
    })

    if names.isEmpty {
      return nil
    } else {
      return names.joined(separator: ", ")
    }
  }

  var transferPlaces: [TripPlace] {
    self.legs[1...].map { $0.fromPlace }
  }

  var firstTransitLeg: TransitLeg? {
    for leg in self.legs {
      if case let .transit(transitLeg) = leg.modeLeg {
        return transitLeg
      }
    }
    return nil
  }

  init(itinerary: Itinerary, from: Place, to: Place) {
    self.id = UUID()
    self.raw = itinerary
    self.legs = itinerary.legs.map { itineraryLeg in
      TripLeg(
        geometry: decodePolyline(itineraryLeg.geometry, precision: 6),
        fromPlace: itineraryLeg.fromPlace,
        toPlace: itineraryLeg.toPlace,
        startTime: itineraryLeg.startTime,
        endTime: itineraryLeg.endTime,
        mode: itineraryLeg.mode,
        modeLeg: itineraryLeg.modeLeg
      )
    }
    self.from = from
    self.to = to
  }
}

extension Trip: CustomStringConvertible {
  var description: String {
    "Trip(from: \(self.from.name), to: \(self.to.name), id: \(self.id)"
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
