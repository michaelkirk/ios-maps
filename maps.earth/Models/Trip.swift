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
  /// The whole route this leg rides part of, for transit legs the server has a shape for.
  var patternGeometry: [CLLocationCoordinate2D]?
  /// Every ordinary stop on the portion of the route the rider travels, in order.
  var riddenStops: [CLLocationCoordinate2D]?
  /// The stops beyond the part the rider is aboard for.
  var contextStops: [CLLocationCoordinate2D]?
  /// The stops where the rider boards and alights, drawn onto the route.
  var onOffStops: [CLLocationCoordinate2D]?
  var fromPlace: TripPlace
  var toPlace: TripPlace
  var startTime: Date
  var endTime: Date
  var mode: TravelMode
  var modeLeg: ModeLeg
  /// The mode of the whole trip this leg is part of.
  var tripMode: TravelMode

  var duration: Duration {
    Duration.seconds(endTime.timeIntervalSince(startTime))
  }

  var transitLeg: TransitLeg? {
    guard case .transit(let transitLeg) = self.modeLeg else {
      return nil
    }
    return transitLeg
  }

  var elevation: LegElevation? {
    guard case .nonTransit(let nonTransitLeg) = self.modeLeg else {
      return nil
    }
    return nonTransitLeg.elevation
  }

  /// Walking and cycling are drawn in the color of their grade.
  var isGraded: Bool {
    mode == .walk || mode == .bike
  }

  /// Walking or cycling to and from transit is dotted, so it doesn't read as the ride itself.
  var isDotted: Bool {
    isGraded && tripMode == .transit
  }

  /// Each straight piece of the leg, with how far along the leg it starts.
  private var segments:
    [(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, start: Double, length: Double)]
  {
    var start = 0.0
    return zip(geometry, geometry.dropFirst()).map { from, to in
      let length = CLLocation(latitude: from.latitude, longitude: from.longitude).distance(
        from: CLLocation(latitude: to.latitude, longitude: to.longitude))
      defer { start += length }
      return (from, to, start, length)
    }
  }

  private static func between(
    _ from: CLLocationCoordinate2D, _ to: CLLocationCoordinate2D, _ t: Double
  ) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(
      latitude: from.latitude + t * (to.latitude - from.latitude),
      longitude: from.longitude + t * (to.longitude - from.longitude))
  }

  /// The point `fraction` of the way along the leg, by distance.
  func pointAlong(fraction: Double) -> CLLocationCoordinate2D {
    let segments = self.segments
    guard let last = segments.last else {
      return geometry[0]
    }
    let target = fraction * (last.start + last.length)
    let segment = segments.first { target <= $0.start + $0.length } ?? last
    let t = segment.length == 0 ? 0 : min((target - segment.start) / segment.length, 1)
    return Self.between(segment.from, segment.to, t)
  }

  /// How far along the leg, as a fraction, its nearest point to `target` is.
  func fractionNearest(_ target: CLLocationCoordinate2D) -> Double {
    // Flat enough at the scale of a leg to project in degrees, once longitude is squeezed to match.
    let lngScale = cos(target.latitude * .pi / 180)
    let targetLocation = CLLocation(latitude: target.latitude, longitude: target.longitude)
    var total = 0.0
    var nearest = (meters: 0.0, distance: Double.infinity)
    for (from, to, start, length) in segments {
      let dx = (to.longitude - from.longitude) * lngScale
      let dy = to.latitude - from.latitude
      let lengthSquared = dx * dx + dy * dy
      let t =
        lengthSquared == 0
        ? 0
        : min(
          max(
            ((target.longitude - from.longitude) * lngScale * dx
              + (target.latitude - from.latitude) * dy) / lengthSquared, 0), 1)
      let projected = Self.between(from, to, t)
      let distance = CLLocation(latitude: projected.latitude, longitude: projected.longitude)
        .distance(from: targetLocation)
      if distance < nearest.distance {
        nearest = (start + t * length, distance)
      }
      total = start + length
    }
    return total == 0 ? 0 : nearest.meters / total
  }

  /// The stretch of the leg from `startMeters` to `endMeters` along it.
  private func slice(startMeters: Double, endMeters: Double) -> [CLLocationCoordinate2D] {
    var piece: [CLLocationCoordinate2D] = []
    for (from, to, start, length) in segments {
      let end = start + length
      if end < startMeters {
        continue
      }
      if start > endMeters {
        break
      }
      let at = { (meters: Double) in
        Self.between(from, to, length == 0 ? 0 : (meters - start) / length)
      }
      if piece.isEmpty {
        piece.append(at(max(startMeters, start)))
      }
      piece.append(at(min(endMeters, end)))
    }
    return piece
  }

  /// The selected line, leaving room for the steep stretches when dotted, since dots drawn over
  /// dots don't line up.
  var selectedGeometry: [[CLLocationCoordinate2D]] {
    guard isDotted, let elevation else {
      return [geometry]
    }
    var pieces: [[CLLocationCoordinate2D]] = []
    var from = 0.0
    for section in elevation.steepSections.sorted(by: { $0.startMeters < $1.startMeters }) {
      pieces.append(slice(startMeters: from, endMeters: section.startMeters))
      from = section.endMeters
    }
    pieces.append(slice(startMeters: from, endMeters: .infinity))
    return pieces.filter { $0.count >= 2 }
  }

  /// Steep stretches of a walking or cycling leg, grouped by how they're drawn.
  var steepSectionsByShade: [(shade: GradeShade, lines: [[CLLocationCoordinate2D]])] {
    let sections = elevation?.steepSections ?? []
    return GradeShade.allCases.compactMap { shade in
      let lines = sections.filter { $0.shade == shade }.map { $0.coordinates }
      return lines.isEmpty ? nil : (shade, lines)
    }
  }

  var activeLineColor: Color {
    if case .transit(let transitLeg) = self.modeLeg,
      let routeColor = transitLeg.route?.color,
      let color = Color(hexString: routeColor)
    {
      color
    } else {
      Color.hw_activeRoute
    }
  }
}

/// Elevations sampled along a path, for legs travelmux didn't plan with OTP.
struct ElevationProfile: Codable {
  let totalClimbMeters: Float64
  let totalFallMeters: Float64
  let elevation: [Float64]

  /// Only the shape matters to the chart, not the true distance between samples, and there are no
  /// steep sections to mark.
  var legElevation: LegElevation {
    LegElevation(
      profile: elevation.enumerated().map {
        LegElevation.ProfilePoint(distance: Double($0.offset), elevation: $0.element)
      },
      totalClimbMeters: totalClimbMeters,
      totalFallMeters: totalFallMeters,
      steepSections: [])
  }
}

struct Trip: Identifiable {
  let raw: Itinerary
  /// For a walking or cycling trip: from the plan, or looked up for one OTP didn't plan.
  private(set) var elevation: LegElevation?
  mutating func setElevationProfile(_ profile: ElevationProfile) {
    self.elevation = Self.drawable(profile.legElevation)
  }

  /// Only a profile the chart can draw, from a start to an end.
  private static func drawable(_ elevation: LegElevation?) -> LegElevation? {
    guard let elevation, elevation.profile.count >= 2 else {
      return nil
    }
    return elevation
  }

  /// e.g. "120 ft": short spans, like a climb or the total climbed
  func formatFeetOrMeters(meters: Double) -> String {
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
    self.raw.durationSeconds
  }

  var startTime: Date {
    self.raw.startTime
  }

  var endTime: Date {
    self.raw.endTime
  }

  var timeSpanFormatted: String {
    let timeStyle = Date.FormatStyle()
      .hour()
      .minute()
    return "\(startTime.formatted(timeStyle)) - \(endTime.formatted(timeStyle))"
  }

  var distanceMeters: Float64 {
    self.raw.distanceMeters
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
    let measurement = Measurement(value: distanceMeters, unit: UnitLength.meters).converted(
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

  /// Where the traveler changes legs, except at a transit stop, which the map already marks with
  /// a stop of its own.
  var transferPlaces: [TripPlace] {
    self.legs.indices.dropFirst().filter {
      self.legs[$0].transitLeg == nil && self.legs[$0 - 1].transitLeg == nil
    }.map { self.legs[$0].fromPlace }
  }

  /// The first leg the traveler rides rather than walks, if this trip has one.
  var firstTransitLeg: TripLeg? {
    self.legs.first { $0.transitLeg != nil }
  }

  /// The transit patterns this trip rides, which is what vehicle positions are keyed by.
  var patternCodes: [String] {
    self.legs.compactMap { $0.transitLeg?.patternCode }
  }

  init(itinerary: Itinerary, from: Place, to: Place) {
    self.id = UUID()
    self.raw = itinerary
    self.legs = itinerary.legs.map { itineraryLeg in
      TripLeg(
        geometry: decodePolyline(itineraryLeg.geometry, precision: 6),
        patternGeometry: itineraryLeg.transitLeg?.patternGeometry.map {
          decodePolyline($0, precision: 6)
        },
        riddenStops: itineraryLeg.transitLeg?.riddenStops.map {
          decodePolyline($0, precision: 6)
        },
        contextStops: itineraryLeg.transitLeg?.contextStops.map {
          decodePolyline($0, precision: 6)
        },
        onOffStops: itineraryLeg.transitLeg?.onOffStops.map {
          decodePolyline($0, precision: 6)
        },
        fromPlace: itineraryLeg.fromPlace,
        toPlace: itineraryLeg.toPlace,
        startTime: itineraryLeg.startTime,
        endTime: itineraryLeg.endTime,
        mode: itineraryLeg.mode,
        modeLeg: itineraryLeg.modeLeg,
        tripMode: itinerary.mode
      )
    }
    self.from = from
    self.to = to
    if self.legs.count == 1, case .nonTransit(let nonTransitLeg) = self.legs[0].modeLeg {
      self.elevation = Self.drawable(nonTransitLeg.elevation)
    }
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
