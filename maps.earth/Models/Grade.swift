//
//  Grade.swift
//  maps.earth
//

import CoreLocation
import SwiftUI
import Turf

/// How hilly a walking or cycling leg is.
struct LegElevation: Decodable, Equatable {
  /// Meters above sea level, by meters along the leg.
  let profile: [ProfilePoint]
  let totalClimbMeters: Double
  let totalFallMeters: Double
  let steepSections: [SteepSection]

  struct ProfilePoint: Decodable, Equatable {
    let distance: Double
    let elevation: Double

    init(distance: Double, elevation: Double) {
      self.distance = distance
      self.elevation = elevation
    }

    /// travelmux sends each point as `[distance, elevation]`.
    init(from decoder: Decoder) throws {
      var container = try decoder.unkeyedContainer()
      self.distance = try container.decode(Double.self)
      self.elevation = try container.decode(Double.self)
    }
  }

  /// The steepest few climbs, spread out enough that their labels don't crowd each other.
  var annotatedClimbs: [SteepSection] {
    steepSections.filter { $0.annotated }
  }

  /// How far along the profile the middle of `section` is, as a fraction.
  func midpointFraction(of section: SteepSection) -> Double {
    let start = profile.first!.distance
    let end = profile.last!.distance
    return ((section.startMeters + section.endMeters) / 2 - start) / (end - start)
  }
}

/// A stretch of a leg steep enough for travelmux to call out.
struct SteepSection: Hashable {
  let startMeters: Double
  let endMeters: Double
  /// Rise over run: positive climbs, negative descends.
  let averageGrade: Double
  let maxGrade: Double
  let streetName: String?
  /// At least two points.
  let geometry: LineString
  /// One of the leg's steepest few climbs, worth labeling.
  let annotated: Bool

  var isClimb: Bool {
    averageGrade > 0
  }

  var tier: GradeTier {
    GradeTier(grade: averageGrade)
  }

  var shade: GradeShade {
    GradeShade(grade: averageGrade)
  }

  /// e.g. 12 for a 12% grade, climbing or descending.
  var percent: Int {
    Int((abs(averageGrade) * 100).rounded())
  }

  /// e.g. "12% steep grade"
  var gradeDescription: String {
    "\(percent)% \(tier.name) grade"
  }
}

extension SteepSection: Decodable {
  private enum CodingKeys: String, CodingKey {
    case startMeters, endMeters, averageGrade, maxGrade, streetName, geometry, annotated
  }

  /// travelmux sends the geometry as an encoded polyline, 1e-6 scale.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      startMeters: try container.decode(Double.self, forKey: .startMeters),
      endMeters: try container.decode(Double.self, forKey: .endMeters),
      averageGrade: try container.decode(Double.self, forKey: .averageGrade),
      maxGrade: try container.decode(Double.self, forKey: .maxGrade),
      streetName: try container.decodeIfPresent(String.self, forKey: .streetName),
      geometry:  LineString(encodedPolyline: try container.decode(String.self, forKey: .geometry)),
      annotated: try container.decode(Bool.self, forKey: .annotated))
  }

  /// Turf's `LineString` isn't `Hashable`; a section's span already tells it apart.
  func hash(into hasher: inout Hasher) {
    hasher.combine(startMeters)
    hasher.combine(endMeters)
  }
}

enum GradeTier {
  case moderate
  case steep
  case verySteep

  init(grade: Double) {
    let steepness = abs(grade)
    if steepness >= 0.13 {
      self = .verySteep
    } else if steepness >= 0.09 {
      self = .steep
    } else {
      self = .moderate
    }
  }

  var name: String {
    switch self {
    case .moderate: "moderate"
    case .steep: "steep"
    case .verySteep: "very steep"
    }
  }
}

/// How a steep stretch is drawn: climbs in amber, darker the steeper, and descents in teal. travelmux
/// only sends descents that are very steep.
enum GradeShade: String, CaseIterable {
  case moderateClimb
  case steepClimb
  case verySteepClimb
  case verySteepDescent

  init(grade: Double) {
    let tier = GradeTier(grade: grade)
    if grade < 0 {
      self = .verySteepDescent
      return
    }
    switch tier {
    case .moderate: self = .moderateClimb
    case .steep: self = .steepClimb
    case .verySteep: self = .verySteepClimb
    }
  }

  var color: Color {
    switch self {
    case .moderateClimb: .hw_amber500
    case .steepClimb: .hw_amber600
    case .verySteepClimb: .hw_amber700
    case .verySteepDescent: .hw_teal700
    }
  }
}

