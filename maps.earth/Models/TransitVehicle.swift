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
  let route: TransitRoute?
  let vehicleMode: TransitVehicleMode?
  let headsign: String?
  /// `FeedId:VehicleId` - internal, and not always the number on the vehicle. Prefer `label`.
  let vehicleId: String?
  /// What the vehicle shows the public, e.g. a bus fleet number.
  let label: String?
  let lat: Float64
  let lon: Float64
  /// When the vehicle reported this position, and when its track begins.
  let lastUpdated: Date?
  /// Absent when travelmux has nothing to predict from - then the vehicle just sits where it is.
  let track: VehicleTrack?
}

/// Predicted positions at a fixed cadence, beginning at the vehicle's `lastUpdated`, so the pair
/// bracketing an instant is arithmetic rather than a search. Everything past the first point is a
/// guess.
struct VehicleTrack {
  let stepSeconds: Float64
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
    // note the spelling: travelmux reports [lat, lon] pairs, maplibre wants them the other way
    self.points = try container.decode([[Float64]].self, forKey: .points).map {
      LngLat(lng: $0[1], lat: $0[0])
    }
  }
}

extension TransitVehicle {
  /// Where the vehicle last actually reported being.
  var reportedLocation: LngLat {
    LngLat(lng: lon, lat: lat)
  }

  /// Where we reckon the vehicle is at `date`, walking the predicted track.
  ///
  /// Before the track begins, or with no track at all, that's just the reported position. Past its
  /// end we hold at the last point rather than running off the end of the prediction.
  func location(at date: Date) -> LngLat {
    guard let track, let reportedAt = lastUpdated, let first = track.points.first,
      track.stepSeconds > 0
    else {
      return reportedLocation
    }

    let elapsed = date.timeIntervalSince(reportedAt) / track.stepSeconds
    guard elapsed > 0 else {
      return first
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
    guard track != nil, let reportedAt = lastUpdated else {
      return false
    }
    return date > reportedAt
  }

  var routeName: String {
    route?.shortName ?? route?.longName ?? ""
  }

  /// The number painted on the vehicle, if it has one.
  ///
  /// Buses publish one; trains and ferries usually don't, in which case we show nothing rather
  /// than an id that isn't written anywhere the rider can see.
  var labelFormatted: String? {
    label.map { "Vehicle \($0)" }
  }

  var color: Color {
    route?.color.flatMap { Color(hexString: $0) } ?? Color.hw_activeRoute
  }

  /// How much of this dot is reported and how much is guesswork, phrased for the traveler.
  ///
  /// Once the dot has left the reported position it says so: the position on screen is one nobody
  /// reported, and the honest thing is to name the last moment we actually knew.
  func freshnessFormatted(at date: Date = .now) -> String {
    guard let lastUpdated else {
      return "Live location"
    }
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
