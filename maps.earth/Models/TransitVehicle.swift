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
  /// Absent when no boarding stop was asked about, or when this vehicle's trip doesn't call there.
  let boardingStop: BoardingStop?
}

/// Which side of the rider's boarding stop a vehicle is on, and when it reaches or reached it.
///
/// The arrival is an instant rather than a countdown: a poll is held for 30 seconds, and a number
/// of minutes would be that stale by the end of one.
enum BoardingStop: Equatable {
  case approaching(arrival: Date, stopsAway: Int?)
  case departed(arrival: Date)
}

extension BoardingStop: Decodable {
  private enum CodingKeys: String, CodingKey {
    case state
    case arrival
    case stopsAway
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let arrival = try container.decode(Date.self, forKey: .arrival)
    switch try container.decode(String.self, forKey: .state) {
    case "approaching":
      self = .approaching(
        arrival: arrival, stopsAway: try container.decodeIfPresent(Int.self, forKey: .stopsAway))
    case "departed":
      self = .departed(arrival: arrival)
    case let state:
      throw DecodingError.dataCorruptedError(
        forKey: .state, in: container, debugDescription: "unknown boarding stop state \(state)")
    }
  }
}

/// How long until a vehicle reaches the stop, with the unit kept apart from the number so a view
/// can set it in smaller type.
struct Countdown: Equatable {
  let value: String
  let unit: String

  init(seconds: TimeInterval) {
    guard seconds >= 60 else {
      self.value = "\(Int(seconds.rounded()))"
      self.unit = "sec"
      return
    }
    let minutes = Int((seconds / 60).rounded())
    guard minutes >= 60 else {
      self.value = "\(minutes)"
      self.unit = "min"
      return
    }
    self.value = String(format: "%d:%02d", minutes / 60, minutes % 60)
    self.unit = "hr"
  }
}

/// What the callout says about the rider's boarding stop: whether this vehicle is still coming,
/// and - while it's still on its way - how long the wait is.
struct BoardingStopRow: Equatable {
  let text: String
  let countdown: Countdown?
}

extension TimeInterval {
  /// A duration phrased for a rider, at the precision its length deserves.
  ///
  /// Under a minute stays in seconds: allowing only minutes would round 40 seconds up to "1 min"
  /// and overstate it.
  fileprivate var durationFormatted: String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = self < 60 ? [.second] : [.hour, .minute]
    return formatter.string(from: self) ?? "\(Int(self))s"
  }
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

  /// Within this much of the boarding stop, a countdown is less use to a waiting rider than being
  /// told to look up.
  private static let arrivingNowSeconds: TimeInterval = 30

  /// The boarding-stop line of the callout: whether this vehicle is still coming, and how long
  /// until it gets here.
  ///
  /// Nil when travelmux had nothing to say about the stop - the callout then just carries the
  /// route and how fresh the position is.
  func boardingStopRow(at date: Date = .now) -> BoardingStopRow? {
    switch boardingStop {
    case .none:
      return nil
    case .departed(let arrival):
      // Nothing left to wait through, so no countdown - just how long ago it went by.
      let ago = max(0, date.timeIntervalSince(arrival))
      return BoardingStopRow(text: "Left \(ago.durationFormatted) ago", countdown: nil)
    case .approaching(let arrival, _):
      let seconds = arrival.timeIntervalSince(date)
      guard seconds > Self.arrivingNowSeconds else {
        return BoardingStopRow(text: "Arriving now", countdown: nil)
      }
      return BoardingStopRow(text: "Approaching", countdown: Countdown(seconds: seconds))
    }
  }

  /// How much of this dot is reported and how much is guesswork, phrased for the traveler.
  ///
  /// Once the dot has left the reported position it says so: the position on screen is one nobody
  /// reported, and the honest thing is to name the last moment we actually knew.
  func freshnessFormatted(at date: Date = .now) -> String {
    let ageText = max(0, date.timeIntervalSince(lastUpdated)).durationFormatted

    if isEstimated(at: date) {
      return "Estimated · confirmed \(ageText) ago"
    } else {
      return "Location as of \(ageText) ago"
    }
  }
}
