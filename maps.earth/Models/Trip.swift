//
//  Trip.swift
//  maps.earth
//
//  Created by Michael Kirk on 3/4/24.
//

import CoreLocation
import Foundation
import Polyline
import SwiftUI
import Turf

struct TripPlace: Hashable, Equatable {
  var location: LngLat
  var name: String?
}

struct TripLeg {
  var geometry: LineString
  /// The whole route this leg rides part of, for transit legs the server has a shape for.
  var patternGeometry: LineString?
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

  /// The point `fraction` of the way along the leg, by distance.
  func pointAlong(fraction: Double) -> CLLocationCoordinate2D {
    geometry.coordinateFromStart(distance: fraction * geometry.distance()!)!
  }

  /// How far along the leg, as a fraction, its nearest point to `target` is.
  func fractionNearest(_ target: CLLocationCoordinate2D) -> Double {
    let nearest = geometry.closestCoordinate(to: target)!.coordinate
    // Not the closest coordinate's own `distance`, which is as the crow flies from the start.
    return geometry.distance(to: nearest)! / geometry.distance()!
  }

  /// The selected line, leaving room for the steep stretches when dotted, since dots drawn over
  /// dots don't line up.
  var selectedGeometry: MultiLineString {
    guard isDotted, let elevation else {
      return MultiLineString([geometry.coordinates])
    }
    var pieces: [LineString?] = []
    var from = 0.0
    for section in elevation.steepSections.sorted(by: { $0.startMeters < $1.startMeters }) {
      pieces.append(geometry.trimmed(from: from, to: section.startMeters))
      from = section.endMeters
    }
    pieces.append(geometry.trimmed(from: from, to: .infinity))
    return MultiLineString(pieces.compactMap { $0?.coordinates }.filter { $0.count >= 2 })
  }

  /// Steep stretches of a walking or cycling leg, grouped by how they're drawn.
  var steepSectionsByShade: [(shade: GradeShade, lines: MultiLineString)] {
    let sections = elevation?.steepSections ?? []
    return GradeShade.allCases.compactMap { shade in
      let lines = sections.filter { $0.shade == shade }.map { $0.geometry.coordinates }
      return lines.isEmpty ? nil : (shade, MultiLineString(lines))
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
        geometry: LineString(encodedPolyline: itineraryLeg.geometry),
        patternGeometry: itineraryLeg.transitLeg?.patternGeometry.map {
          LineString(encodedPolyline: $0)
        },
        riddenStops: itineraryLeg.transitLeg?.riddenStops.map {
          decodePolyline($0)
        },
        contextStops: itineraryLeg.transitLeg?.contextStops.map {
          decodePolyline($0)
        },
        onOffStops: itineraryLeg.transitLeg?.onOffStops.map {
          decodePolyline($0)
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

/// From one of travelmux's encoded polylines, 1e-6 scale.
func decodePolyline(_ encodedPolyline: String) -> [LocationCoordinate2D] {
  Polyline(encodedPolyline: encodedPolyline, precision: 1e6).coordinates!
}

extension Turf.LineString {
  /// From one of travelmux's encoded polylines, 1e-6 scale.
  init(encodedPolyline: String) {
    self.init(decodePolyline(encodedPolyline))
  }
}
