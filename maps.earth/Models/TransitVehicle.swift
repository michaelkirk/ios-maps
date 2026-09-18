//
//  TransitVehicle.swift
//  maps.earth
//
//  Created by Michael Kirk on 9/17/26.
//

import Foundation
import SwiftUI

/// Where a transit vehicle last reported being, and where travelmux reckons it goes next.
struct TransitVehicle: Decodable, Identifiable {
  /// Stable for as long as the vehicle keeps reporting on this pattern, so it can key a marker.
  let id: String
  let patternCode: String
  let route: TransitRoute
  let vehicleMode: TransitVehicleMode?
  let headsign: String?
  /// `FeedId:VehicleId` - internal, and not always the number on the vehicle. Prefer `label`.
  let vehicleId: String?
  /// What the vehicle shows the public, e.g. a bus fleet number.
  let label: String?
  /// Where the vehicle last reported being.
  let position: LonLatPair
  /// When the vehicle reported this position, and when its track begins.
  let lastUpdated: Date
  /// Absent when travelmux has nothing to predict from - then the vehicle just sits where it is.
  let track: VehicleTrack?
}

/// Predicted positions at a fixed cadence, beginning at the vehicle's `lastUpdated`, so the pair
/// bracketing an instant is arithmetic rather than a search. Everything past the first point is a
/// guess.
struct VehicleTrack {
  let stepSeconds: Float64
  /// At least two, so walking the track is always between a pair of them.
  let points: [LngLat]
}

extension VehicleTrack: Decodable {
  private enum CodingKeys: String, CodingKey {
    case stepSeconds
    case points
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.stepSeconds = try container.decode(Float64.self, forKey: .stepSeconds)
    let points = try container.decode([LonLatPair].self, forKey: .points).map(\.lngLat)
    // travelmux only sends a track it can walk, and refusing a shorter one here is what lets
    // everything below index into it.
    guard points.count >= 2 else {
      throw DecodingError.dataCorruptedError(
        forKey: .points, in: container, debugDescription: "a track needs at least two points")
    }
    self.points = points
  }
}

extension TransitVehicle {
  /// Where the vehicle last actually reported being.
  var reportedLocation: LngLat {
    position.lngLat
  }

  /// Where we reckon the vehicle is at `date`, walking the predicted track.
  ///
  /// Before the track begins, or with no track at all, that's just the reported position. Past its
  /// end we hold at the last point rather than running off the end of the prediction.
  func location(at date: Date) -> LngLat {
    guard let track else {
      return reportedLocation
    }

    let elapsed = date.timeIntervalSince(lastUpdated) / track.stepSeconds
    guard elapsed > 0 else {
      return track.points[0]
    }

    let lastIdx = track.points.count - 1
    guard elapsed < Float64(lastIdx) else {
      return track.points[lastIdx]
    }

    let idx = Int(elapsed)
    let into = elapsed - Float64(idx)
    let from = track.points[idx]
    let to = track.points[idx + 1]
    return LngLat(
      lng: from.lng + into * (to.lng - from.lng),
      lat: from.lat + into * (to.lat - from.lat))
  }

  /// Whether the dot has moved past the last thing the vehicle actually told us.
  func isEstimated(at date: Date) -> Bool {
    track != nil && date > lastUpdated
  }

  var routeName: String {
    route.shortName ?? route.longName ?? ""
  }

  /// A vehicle whose feed names no mode is still some kind of transit.
  var emoji: String {
    (vehicleMode ?? .transit).emoji
  }

  /// Only the short name is badged: a long one ("Downtown - Ballard") doesn't fit beside the chip,
  /// so a route without one goes unbadged.
  var badge: String? {
    route.shortName
  }

  /// The number painted on the vehicle, if it has one.
  ///
  /// Buses publish one; trains and ferries usually don't, in which case we show nothing rather
  /// than an id that isn't written anywhere the rider can see.
  var labelFormatted: String? {
    label.map { "Vehicle \($0)" }
  }

  var color: Color {
    route.color.flatMap { Color(hexString: $0) } ?? Color.hw_activeRoute
  }

  /// How much of this dot is reported and how much is guesswork, phrased for the traveler.
  ///
  /// Once the dot has left the reported position it says so: the position on screen is one nobody
  /// reported, and the honest thing is to name the last moment we actually knew.
  func freshnessFormatted(at date: Date = .now) -> String {
    let age = max(0, date.timeIntervalSince(lastUpdated))
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    // Positions refresh about once a minute, so most ages land under one - where allowing only
    // minutes would round 40 seconds up to "1 min" and overstate how fresh this is.
    formatter.allowedUnits = age < 60 ? [.second] : [.hour, .minute]
    let ageText = formatter.string(from: age) ?? "\(Int(age)) sec"

    if isEstimated(at: date) {
      return "Estimated · confirmed \(ageText) ago"
    } else {
      return "Location as of \(ageText) ago"
    }
  }
}
